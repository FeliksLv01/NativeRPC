#!/usr/bin/env node

/**
 * NativeRPC Code Generator CLI
 */

import { Command } from 'commander';
import * as fs from 'fs';
import * as path from 'path';
import { NativeRPCCodeGenerator } from '../index';
import { Configuration } from '../config';

const program = new Command();

program
  .name('nativerpc-codegen')
  .description('Generate type-safe clients and service stubs from TypeScript definitions')
  .version('1.0.0');

program
  .command('generate')
  .description('Generate code from TypeScript service definitions')
  .option('-c, --config <path>', 'Path to configuration file', 'nativerpc.config.json')
  .option('-o, --output <path>', 'Override output directory')
  .option('--dart', 'Generate only Dart code')
  .option('--swift', 'Generate only Swift code')
  .option('--kotlin', 'Generate only Kotlin code')
  .option('--typescript', 'Generate only TypeScript code')
  .option('--dry-run', 'Show what would be generated without writing files')
  .option('-v, --verbose', 'Show verbose output')
  .action(async (options) => {
    try {
      // Load configuration
      const configPath = path.resolve(process.cwd(), options.config);
      
      if (!fs.existsSync(configPath)) {
        console.error(`Configuration file not found: ${configPath}`);
        process.exit(1);
      }
      
      const configContent = fs.readFileSync(configPath, 'utf-8');
      const config: Configuration = JSON.parse(configContent);
      
      // Override output paths if specified
      if (options.output) {
        if (config.rendering.dart) {
          config.rendering.dart.outputPath = path.join(options.output, 'dart');
        }
        if (config.rendering.swift) {
          config.rendering.swift.outputPath = path.join(options.output, 'swift');
        }
        if (config.rendering.kotlin) {
          config.rendering.kotlin.outputPath = path.join(options.output, 'kotlin');
        }
        if (config.rendering.typescript) {
          config.rendering.typescript.outputPath = path.join(options.output, 'typescript');
        }
      }
      
      // Filter languages if specified
      if (options.dart || options.swift || options.kotlin || options.typescript) {
        if (!options.dart) delete config.rendering.dart;
        if (!options.swift) delete config.rendering.swift;
        if (!options.kotlin) delete config.rendering.kotlin;
        if (!options.typescript) delete config.rendering.typescript;
      }
      
      // Resolve source paths relative to config file
      const configDir = path.dirname(configPath);
      config.parsing.sources = config.parsing.sources.map(
        source => path.resolve(configDir, source)
      );
      
      if (options.verbose) {
        console.log('Configuration:', JSON.stringify(config, null, 2));
      }
      
      // Set up template directory
      const templateDir = path.resolve(__dirname, '../../templates');
      
      // Generate code
      const generator = new NativeRPCCodeGenerator(config);
      generator.setTemplateDir(templateDir);
      const result = await generator.generate();
      
      // Output results
      if (options.dryRun) {
        console.log('Dry run - the following files would be generated:');
        for (const file of result.files) {
          console.log(`  ${file.language}: ${file.path}`);
        }
      } else {
        // Write files
        for (const file of result.files) {
          const dir = path.dirname(file.path);
          if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
          }
          fs.writeFileSync(file.path, file.content, 'utf-8');
          console.log(`✓ Generated: ${file.path}`);
        }
      }
      
      // Show warnings
      for (const warning of result.warnings) {
        console.warn(`⚠ Warning: ${warning}`);
      }
      
      // Show errors
      for (const error of result.errors) {
        console.error(`✗ Error: ${error}`);
      }
      
      if (result.success) {
        console.log(`\n✓ Generation complete! ${result.files.length} files generated.`);
      } else {
        console.error('\n✗ Generation failed.');
        process.exit(1);
      }
      
    } catch (error) {
      console.error('Error:', error instanceof Error ? error.message : error);
      process.exit(1);
    }
  });

program
  .command('init')
  .description('Create a sample configuration file')
  .option('-f, --force', 'Overwrite existing config file')
  .action((options) => {
    const configPath = path.resolve(process.cwd(), 'nativerpc.config.json');
    
    if (fs.existsSync(configPath) && !options.force) {
      console.error('Configuration file already exists. Use --force to overwrite.');
      process.exit(1);
    }
    
    const sampleConfig: Configuration = {
      parsing: {
        sources: ['./services/*.ts'],
        dropInterfaceIPrefix: true,
      },
      rendering: {
        dart: {
          outputPath: './generated/dart',
        },
        swift: {
          outputPath: './generated/swift',
          imports: ['NativeRPCKit'],
          baseClass: 'NativeRPCService',
        },
        kotlin: {
          outputPath: './generated/kotlin',
          packageName: 'com.example.services',
          imports: ['com.example.nativerpc.*'],
          baseClass: 'NativeRPCService',
        },
      },
    };
    
    fs.writeFileSync(configPath, JSON.stringify(sampleConfig, null, 2), 'utf-8');
    console.log(`✓ Created configuration file: ${configPath}`);
    console.log('\nNext steps:');
    console.log('  1. Edit nativerpc.config.json to match your project');
    console.log('  2. Create TypeScript service definitions');
    console.log('  3. Run: nativerpc-codegen generate');
  });

program
  .command('diff')
  .description('Show what methods would be added/removed')
  .option('-c, --config <path>', 'Path to configuration file', 'nativerpc.config.json')
  .action(async (options) => {
    console.log('Analyzing differences...');
    // TODO: Implement diff analysis
    console.log('This feature is coming soon.');
  });

program.parse();
