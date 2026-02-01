/**
 * NativeRPC Code Generator - Main Entry Point
 */

export * from './types';
export * from './config';
export * from './merger';
export * from './renderer';
export * from './parser';
export * from './validator';

import * as fs from 'fs';
import * as path from 'path';
import { Configuration } from './config';
import { ServiceModule } from './types';
import { ServiceParser } from './parser';
import { ServiceValidator, formatValidationMessages, ValidationSeverity } from './validator';
import {
  SwiftRenderer,
  KotlinRenderer,
  DartRenderer,
  TypeScriptRenderer,
} from './renderer';

/**
 * Main generator class
 */
export class NativeRPCCodeGenerator {
  private templateDir: string;
  private serviceSuffix: string;
  
  constructor(private readonly config: Configuration) {
    // Resolve template directory (relative to config file or absolute)
    this.templateDir = path.resolve(
      path.dirname(process.cwd()),
      'templates'
    );
    
    // If templateDir in config, use that
    if ((config as any).templateDir) {
      this.templateDir = path.resolve((config as any).templateDir);
    }
    
    // Service suffix (default: "RPCService")
    this.serviceSuffix = config.rendering.serviceSuffix || 'RPCService';
  }
  
  /**
   * Set custom template directory
   */
  setTemplateDir(dir: string): void {
    this.templateDir = path.resolve(dir);
  }
  
  /**
   * Run the code generator
   */
  async generate(): Promise<GenerationResult> {
    const result: GenerationResult = {
      success: true,
      files: [],
      errors: [],
      warnings: [],
    };
    
    try {
      // 1. Parse TypeScript sources
      const modules = await this.parseSource();
      
      if (modules.length === 0) {
        result.warnings.push('No service definitions found in source files');
        return result;
      }
      
      console.log(`Found ${modules.length} service module(s)`);
      
      // 2. Validate services
      const validator = new ServiceValidator();
      const validationResult = validator.validateAll(modules);
      
      // Add validation messages to result
      for (const msg of validationResult.messages) {
        const formatted = `[${msg.code}] ${msg.message}${msg.location?.service ? ` in ${msg.location.service}` : ''}`;
        if (msg.severity === ValidationSeverity.Error) {
          result.errors.push(formatted);
        } else if (msg.severity === ValidationSeverity.Warning) {
          result.warnings.push(formatted);
        }
      }
      
      // Print validation summary
      if (validationResult.messages.length > 0) {
        console.log(formatValidationMessages(validationResult.messages));
      }
      
      // Stop if validation failed
      if (!validationResult.valid) {
        result.success = false;
        console.error('\n❌ Validation failed. Fix errors before generating code.');
        return result;
      }
      
      // 3. Generate Dart code
      if (this.config.rendering.dart) {
        const dartFiles = await this.generateDart(modules);
        result.files.push(...dartFiles);
      }
      
      // 4. Generate TypeScript code
      if (this.config.rendering.typescript) {
        const tsFiles = await this.generateTypeScript(modules);
        result.files.push(...tsFiles);
      }
      
      // 5. Generate Swift code
      if (this.config.rendering.swift) {
        const swiftFiles = await this.generateSwift(modules);
        result.files.push(...swiftFiles);
      }
      
      // 6. Generate Kotlin code
      if (this.config.rendering.kotlin) {
        const kotlinFiles = await this.generateKotlin(modules);
        result.files.push(...kotlinFiles);
      }
      
    } catch (error) {
      result.success = false;
      const errorMessage = error instanceof Error ? error.message : String(error);
      result.errors.push(errorMessage);
      console.error(`\n❌ Generation error: ${errorMessage}`);
      if (error instanceof Error && error.stack) {
        console.error(error.stack);
      }
    }
    
    return result;
  }
  
  private async parseSource(): Promise<ServiceModule[]> {
    console.log('Parsing sources:', this.config.parsing.sources);
    
    const parser = new ServiceParser(this.config.parsing.sources, {
      dropInterfaceIPrefix: true,
      predefinedTypes: this.config.parsing.predefinedTypes,
      tsconfigPath: this.config.parsing.tsconfigPath,
    });
    
    const modules = parser.parse();
    
    // Log found modules
    for (const module of modules) {
      console.log(`  - ${module.name}: ${module.methods.length} methods, ${module.events.length} events`);
    }
    
    return modules;
  }
  
  private async generateDart(modules: ServiceModule[]): Promise<GeneratedFile[]> {
    console.log('Generating Dart code for', modules.length, 'modules');
    
    const dartConfig = this.config.rendering.dart!;
    const templateDir = path.join(this.templateDir, 'dart');
    const renderer = new DartRenderer(templateDir, this.serviceSuffix);
    const files: GeneratedFile[] = [];
    
    for (const module of modules) {
      const content = renderer.render(module, 'service-client.mustache');
      // Use service naming with configurable suffix
      const baseName = module.name.replace(/Service$/, '');
      const className = `${baseName}${this.serviceSuffix}`;
      const fileName = `${this.toSnakeCase(className)}.dart`;
      const filePath = path.join(dartConfig.outputPath, fileName);
      
      files.push({
        path: filePath,
        content,
        language: 'dart',
      });
    }
    
    return files;
  }
  
  private async generateTypeScript(modules: ServiceModule[]): Promise<GeneratedFile[]> {
    console.log('Generating TypeScript code for', modules.length, 'modules');
    
    const tsConfig = this.config.rendering.typescript!;
    const templateDir = path.join(this.templateDir, 'typescript');
    const renderer = new TypeScriptRenderer(templateDir, this.serviceSuffix);
    const files: GeneratedFile[] = [];
    
    for (const module of modules) {
      const content = renderer.render(module, 'service-client.mustache');
      // Use service naming with configurable suffix
      const baseName = module.name.replace(/Service$/, '');
      const className = `${baseName}${this.serviceSuffix}`;
      const fileName = `${this.toKebabCase(className)}.ts`;
      const filePath = path.join(tsConfig.outputPath, fileName);
      
      files.push({
        path: filePath,
        content,
        language: 'typescript',
      });
    }
    
    return files;
  }
  
  private async generateSwift(modules: ServiceModule[]): Promise<GeneratedFile[]> {
    console.log('Generating Swift code for', modules.length, 'modules');
    
    const swiftConfig = this.config.rendering.swift!;
    const templateDir = path.join(this.templateDir, 'swift');
    const renderer = new SwiftRenderer(templateDir, this.serviceSuffix);
    const files: GeneratedFile[] = [];
    
    for (const module of modules) {
      // Use service naming with configurable suffix
      const baseName = module.name.replace(/Service$/, '');
      const className = `${baseName}${this.serviceSuffix}`;
      const fileName = `${className}.swift`;
      const existingPath = swiftConfig.existingServicePath 
        ? path.join(swiftConfig.existingServicePath, fileName)
        : undefined;
      
      const content = renderer.renderWithMerge(module, existingPath);
      const filePath = path.join(swiftConfig.outputPath, fileName);
      
      files.push({
        path: filePath,
        content,
        language: 'swift',
      });
    }
    
    return files;
  }
  
  private async generateKotlin(modules: ServiceModule[]): Promise<GeneratedFile[]> {
    console.log('Generating Kotlin code for', modules.length, 'modules');
    
    const kotlinConfig = this.config.rendering.kotlin!;
    const templateDir = path.join(this.templateDir, 'kotlin');
    const packageName = kotlinConfig.packageName || 'com.itoken.team';
    const renderer = new KotlinRenderer(templateDir, packageName, this.serviceSuffix);
    const files: GeneratedFile[] = [];
    
    for (const module of modules) {
      // Use service naming with configurable suffix
      const baseName = module.name.replace(/Service$/, '');
      const className = `${baseName}${this.serviceSuffix}`;
      const fileName = `${className}.kt`;
      const existingPath = kotlinConfig.existingServicePath
        ? path.join(kotlinConfig.existingServicePath, fileName)
        : undefined;
      
      const content = renderer.renderWithMerge(module, existingPath);
      const filePath = path.join(kotlinConfig.outputPath, fileName);
      
      files.push({
        path: filePath,
        content,
        language: 'kotlin',
      });
    }
    
    return files;
  }
  
  // ============================================================================
  // Utility Functions
  // ============================================================================
  
  /**
   * Convert PascalCase/camelCase to snake_case.
   * Handles acronyms like "RPC" properly: CounterRPCService -> counter_rpc_service
   */
  private toSnakeCase(str: string): string {
    return str
      // Insert underscore before sequences of capitals followed by lowercase
      // e.g., "RPCService" -> "RPC_Service"
      .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
      // Insert underscore between lowercase and uppercase
      // e.g., "Counter" -> "Counter", "counterRPC" -> "counter_RPC"
      .replace(/([a-z\d])([A-Z])/g, '$1_$2')
      .toLowerCase();
  }
  
  /**
   * Convert PascalCase/camelCase to kebab-case.
   * Handles acronyms like "RPC" properly: CounterRPCService -> counter-rpc-service
   */
  private toKebabCase(str: string): string {
    return str
      // Insert hyphen before sequences of capitals followed by lowercase
      .replace(/([A-Z]+)([A-Z][a-z])/g, '$1-$2')
      // Insert hyphen between lowercase and uppercase
      .replace(/([a-z\d])([A-Z])/g, '$1-$2')
      .toLowerCase();
  }
}

/**
 * Result of code generation
 */
export interface GenerationResult {
  success: boolean;
  files: GeneratedFile[];
  errors: string[];
  warnings: string[];
}

/**
 * A generated file
 */
export interface GeneratedFile {
  path: string;
  content: string;
  language: 'dart' | 'typescript' | 'swift' | 'kotlin';
}

/**
 * Write generated files to disk
 */
export async function writeGeneratedFiles(
  files: GeneratedFile[],
  dryRun: boolean = false
): Promise<void> {
  for (const file of files) {
    if (dryRun) {
      console.log(`[Dry Run] Would write: ${file.path}`);
      console.log('---');
      console.log(file.content);
      console.log('---\n');
    } else {
      // Ensure directory exists
      const dir = path.dirname(file.path);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      
      fs.writeFileSync(file.path, file.content, 'utf-8');
      console.log(`Written: ${file.path}`);
    }
  }
}
