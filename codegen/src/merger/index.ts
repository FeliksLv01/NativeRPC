/**
 * NativeRPC Code Generator - Incremental Merger
 * 
 * This module handles merging newly generated code with existing code,
 * preserving method implementations while updating signatures.
 */

import * as fs from 'fs';
import * as path from 'path';

/**
 * Represents an extracted method from existing code
 */
export interface ExtractedMethod {
  /** Method name */
  name: string;
  
  /** Full method signature line */
  signature: string;
  
  /** Method body (content inside the closure/block) */
  body: string;
  
  /** Start line in the original file */
  startLine: number;
  
  /** End line in the original file */
  endLine: number;
}

/**
 * Result of parsing an existing service file
 */
export interface ExistingServiceInfo {
  /** All extracted methods */
  methods: Map<string, ExtractedMethod>;
  
  /** Raw file content */
  content: string;
  
  /** File path */
  filePath: string;
}

/**
 * Merger for Swift service files
 */
export class SwiftServiceMerger {
  /**
   * Parse an existing Swift service file and extract method implementations
   */
  parseExisting(filePath: string): ExistingServiceInfo | null {
    if (!fs.existsSync(filePath)) {
      return null;
    }
    
    const content = fs.readFileSync(filePath, 'utf-8');
    const methods = this.extractMethods(content);
    
    return {
      methods,
      content,
      filePath,
    };
  }
  
  /**
   * Extract method implementations from Swift code
   * 
   * Looks for patterns like:
   * Function("methodName") { (args) -> ReturnType in
   *   // implementation
   * }
   * 
   * AsyncFunction("methodName") { (args) async throws -> ReturnType in
   *   // implementation
   * }
   */
  private extractMethods(content: string): Map<string, ExtractedMethod> {
    const methods = new Map<string, ExtractedMethod>();
    const lines = content.split('\n');
    
    // Pattern to match Function/AsyncFunction definitions
    // Matches: Function("name") { ... in     (with parameters)
    // Matches: AsyncFunction("name") { ... in
    // Matches: Function("name") {            (void without parameters - no 'in')
    const functionStartPattern = /(?:Async)?Function\("(\w+)"\)\s*\{/;
    
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      const match = line.match(functionStartPattern);
      
      if (match) {
        const methodName = match[1];
        const startLine = i;
        
        // Find the closing brace by tracking brace depth
        let braceDepth = 0;
        let foundOpenBrace = false;
        let endLine = i;
        let bodyLines: string[] = [];
        
        for (let j = i; j < lines.length; j++) {
          const currentLine = lines[j];
          
          // Count braces
          for (const char of currentLine) {
            if (char === '{') {
              braceDepth++;
              foundOpenBrace = true;
            } else if (char === '}') {
              braceDepth--;
            }
          }
          
          // Collect body lines (skip the signature line itself)
          if (j > i) {
            // Check if this is the closing brace line
            if (foundOpenBrace && braceDepth === 0) {
              endLine = j;
              break;
            }
            bodyLines.push(currentLine);
          }
          
          if (foundOpenBrace && braceDepth === 0) {
            endLine = j;
            break;
          }
        }
        
        // Note: The closing brace of the Function closure is NOT included in bodyLines
        // because the loop breaks before adding it. So we should NOT remove any trailing }
        // as it might be part of the actual implementation (e.g., a switch statement's closing brace).
        
        methods.set(methodName, {
          name: methodName,
          signature: line,
          body: bodyLines.join('\n'),
          startLine,
          endLine,
        });
        
        i = endLine + 1;
      } else {
        i++;
      }
    }
    
    return methods;
  }
  
  /**
   * Get the implementation body for a method, or null if not found
   */
  getExistingImplementation(existing: ExistingServiceInfo | null, methodName: string): string | null {
    if (!existing) return null;
    
    const method = existing.methods.get(methodName);
    if (!method) return null;
    
    // Check if the body is just a TODO placeholder
    const trimmedBody = method.body.trim();
    if (trimmedBody.includes('TODO: Implement') || 
        trimmedBody.includes('fatalError("Not implemented') ||
        trimmedBody.includes('throw NotImplementedError')) {
      return null;
    }
    
    return method.body;
  }
}

/**
 * Merger for Kotlin service files
 */
export class KotlinServiceMerger {
  /**
   * Parse an existing Kotlin service file and extract method implementations
   */
  parseExisting(filePath: string): ExistingServiceInfo | null {
    if (!fs.existsSync(filePath)) {
      return null;
    }
    
    const content = fs.readFileSync(filePath, 'utf-8');
    const methods = this.extractMethods(content);
    
    return {
      methods,
      content,
      filePath,
    };
  }
  
  /**
   * Extract method implementations from Kotlin code
   * 
   * Looks for patterns like:
   * function("methodName") { args ->
   *   // implementation
   * }
   * 
   * suspendFunction("methodName") { args ->
   *   // implementation
   * }
   */
  private extractMethods(content: string): Map<string, ExtractedMethod> {
    const methods = new Map<string, ExtractedMethod>();
    const lines = content.split('\n');
    
    // Pattern to match function/suspendFunction definitions
    const functionStartPattern = /(?:suspend)?[Ff]unction\("(\w+)"\)\s*\{/;
    
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      const match = line.match(functionStartPattern);
      
      if (match) {
        const methodName = match[1];
        const startLine = i;
        
        // Find the closing brace by tracking brace depth
        let braceDepth = 0;
        let foundOpenBrace = false;
        let endLine = i;
        let bodyLines: string[] = [];
        
        for (let j = i; j < lines.length; j++) {
          const currentLine = lines[j];
          
          // Count braces
          for (const char of currentLine) {
            if (char === '{') {
              braceDepth++;
              foundOpenBrace = true;
            } else if (char === '}') {
              braceDepth--;
            }
          }
          
          // Collect body lines
          if (j > i) {
            if (foundOpenBrace && braceDepth === 0) {
              endLine = j;
              break;
            }
            bodyLines.push(currentLine);
          }
          
          if (foundOpenBrace && braceDepth === 0) {
            endLine = j;
            break;
          }
        }
        
        // Note: The closing brace of the function closure is NOT included in bodyLines
        // because the loop breaks before adding it. So we should NOT remove any trailing }
        // as it might be part of the actual implementation.
        
        // Remove the arrow line if it's the first line (e.g., "args ->")
        if (bodyLines.length > 0) {
          const firstLine = bodyLines[0].trim();
          if (firstLine.endsWith('->')) {
            bodyLines.shift();
          }
        }
        
        methods.set(methodName, {
          name: methodName,
          signature: line,
          body: bodyLines.join('\n'),
          startLine,
          endLine,
        });
        
        i = endLine + 1;
      } else {
        i++;
      }
    }
    
    return methods;
  }
  
  /**
   * Get the implementation body for a method, or null if not found
   */
  getExistingImplementation(existing: ExistingServiceInfo | null, methodName: string): string | null {
    if (!existing) return null;
    
    const method = existing.methods.get(methodName);
    if (!method) return null;
    
    // Check if the body is just a TODO placeholder
    const trimmedBody = method.body.trim();
    if (trimmedBody.includes('TODO: Implement') || 
        trimmedBody.includes('throw NotImplementedError')) {
      return null;
    }
    
    return method.body;
  }
}

/**
 * Generate a diff report showing what methods were added/removed/changed
 */
export interface DiffReport {
  /** Methods that exist in the new definition but not in the existing file */
  added: string[];
  
  /** Methods that exist in the existing file but not in the new definition */
  removed: string[];
  
  /** Methods that exist in both */
  unchanged: string[];
  
  /** Methods that had their signature changed */
  signatureChanged: string[];
}

export function generateDiffReport(
  existingMethods: Set<string>,
  newMethods: Set<string>
): DiffReport {
  const added: string[] = [];
  const removed: string[] = [];
  const unchanged: string[] = [];
  
  for (const method of newMethods) {
    if (existingMethods.has(method)) {
      unchanged.push(method);
    } else {
      added.push(method);
    }
  }
  
  for (const method of existingMethods) {
    if (!newMethods.has(method)) {
      removed.push(method);
    }
  }
  
  return {
    added,
    removed,
    unchanged,
    signatureChanged: [], // Would require comparing signatures
  };
}

export function formatDiffReport(report: DiffReport): string {
  const lines: string[] = ['=== Method Diff Report ===', ''];
  
  if (report.added.length > 0) {
    lines.push('➕ Added methods:');
    for (const method of report.added) {
      lines.push(`   + ${method}`);
    }
    lines.push('');
  }
  
  if (report.removed.length > 0) {
    lines.push('➖ Removed methods (implementation will be lost):');
    for (const method of report.removed) {
      lines.push(`   - ${method}`);
    }
    lines.push('');
  }
  
  if (report.unchanged.length > 0) {
    lines.push(`✓ ${report.unchanged.length} methods unchanged`);
    lines.push('');
  }
  
  return lines.join('\n');
}
