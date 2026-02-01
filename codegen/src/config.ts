/**
 * NativeRPC Code Generator - Configuration
 */

/**
 * Main configuration for the code generator
 */
export interface Configuration {
  /** Parsing configuration */
  parsing: ParsingConfiguration;
  
  /** Rendering configuration */
  rendering: RenderingConfiguration;
}

/**
 * Parsing configuration
 */
export interface ParsingConfiguration {
  /** Source TypeScript files (glob patterns) */
  sources: string[];
  
  /** Path to tsconfig.json (optional) */
  tsconfigPath?: string;
  
  /** Predefined types that should not be parsed (e.g., "Int", "Date") */
  predefinedTypes?: string[];
  
  /** Drop 'I' prefix from interface names */
  dropInterfaceIPrefix?: boolean;
}

/**
 * Rendering configuration for all target languages
 */
export interface RenderingConfiguration {
  /** 
   * Service class name suffix (default: "RPCService")
   * e.g., with suffix "RPCService", CounterService becomes CounterRPCService
   */
  serviceSuffix?: string;
  
  /** Dart rendering configuration */
  dart?: DartRenderConfiguration;
  
  /** TypeScript rendering configuration */
  typescript?: TypeScriptRenderConfiguration;
  
  /** Swift rendering configuration */
  swift?: SwiftRenderConfiguration;
  
  /** Kotlin rendering configuration */
  kotlin?: KotlinRenderConfiguration;
}

/**
 * Base render configuration shared by all languages
 */
interface BaseRenderConfiguration {
  /** Output directory */
  outputPath: string;
  
  /** Custom template path (optional, uses built-in if not specified) */
  templatePath?: string;
  
  /** Type name mapping (e.g., { "Int": "int" }) */
  typeNameMap?: Record<string, string>;
}

/**
 * Dart-specific rendering configuration
 */
export interface DartRenderConfiguration extends BaseRenderConfiguration {
  /** Package name for imports */
  packageName?: string;
  
  /** File name for shared types */
  sharedTypesFileName?: string;
}

/**
 * TypeScript-specific rendering configuration
 */
export interface TypeScriptRenderConfiguration extends BaseRenderConfiguration {
  /** Whether to use ES modules */
  useESModules?: boolean;
}

/**
 * Swift-specific rendering configuration
 */
export interface SwiftRenderConfiguration extends BaseRenderConfiguration {
  /** Existing service file to merge with (for incremental update) */
  existingServicePath?: string;
  
  /** Import statements to include */
  imports?: string[];
  
  /** Base class for generated services */
  baseClass?: string;
}

/**
 * Kotlin-specific rendering configuration
 */
export interface KotlinRenderConfiguration extends BaseRenderConfiguration {
  /** Existing service file to merge with (for incremental update) */
  existingServicePath?: string;
  
  /** Package name */
  packageName?: string;
  
  /** Import statements to include */
  imports?: string[];
  
  /** Base class for generated services */
  baseClass?: string;
}

/**
 * Example configuration file
 */
export const exampleConfig: Configuration = {
  parsing: {
    sources: ['./services/*.ts'],
    dropInterfaceIPrefix: true,
  },
  rendering: {
    serviceSuffix: 'RPCService',
    dart: {
      outputPath: './generated/dart',
      packageName: 'native_rpc_client',
    },
    typescript: {
      outputPath: './generated/ts',
      useESModules: true,
    },
    swift: {
      outputPath: './generated/swift',
      existingServicePath: './ios/Services',
      imports: ['NativeRPCKit'],
      baseClass: 'NativeRPCService',
    },
    kotlin: {
      outputPath: './generated/kotlin',
      existingServicePath: './android/app/src/main/java/com/itoken/team/services',
      packageName: 'com.itoken.team',
      imports: ['com.itoken.team.nativerpc.*'],
      baseClass: 'NativeRPCService',
    },
  },
};
