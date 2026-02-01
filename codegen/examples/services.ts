/**
 * NativeRPC Service Definition Example
 * 
 * This file demonstrates the TypeScript syntax for defining NativeRPC services.
 * The code generator will parse this file and generate:
 * - Dart: Type-safe client for Flutter
 * - TypeScript: Type-safe client for Web
 * - Swift: Service stub with method signatures (incremental update supported)
 * - Kotlin: Service stub with method signatures (incremental update supported)
 * 
 * @module counter
 */

// ============================================================================
// Custom Types
// ============================================================================

/**
 * Counter statistics
 */
export interface CounterStats {
  /** Total number of increments */
  incrementCount: number;
  
  /** Total number of decrements */
  decrementCount: number;
  
  /** Peak value reached */
  peakValue: number;
  
  /** Lowest value reached */
  lowestValue: number;
}

/**
 * Counter operation result
 */
export interface CounterResult {
  /** The new counter value */
  value: number;
  
  /** Timestamp of the operation */
  timestamp: number;
  
  /** Operation that was performed */
  operation: CounterOperation;
}

/**
 * Types of counter operations
 */
export enum CounterOperation {
  Increment = 'increment',
  Decrement = 'decrement',
  Add = 'add',
  Reset = 'reset',
}

// ============================================================================
// Event Payloads
// ============================================================================

/**
 * Payload for count changed events
 */
export interface CountChangedPayload {
  /** Previous count value */
  previousValue: number;
  
  /** New count value */
  newValue: number;
  
  /** What caused the change */
  operation: CounterOperation;
}

// ============================================================================
// Service Definition
// ============================================================================

/**
 * Counter Service
 * 
 * A simple counter service demonstrating NativeRPC capabilities.
 * Supports both synchronous and asynchronous operations.
 * 
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  // ==========================================================================
  // Synchronous Methods (return value directly)
  // ==========================================================================
  
  /**
   * Get the current counter value
   * @returns Current value
   */
  getValue(): number;
  
  /**
   * Increment the counter by 1
   * @returns New value after increment
   */
  increment(): number;
  
  /**
   * Decrement the counter by 1
   * @returns New value after decrement
   */
  decrement(): number;
  
  /**
   * Add a value to the counter
   * @param value - Amount to add (can be negative)
   * @returns New value after addition
   */
  add(args: { value: number }): number;
  
  /**
   * Reset the counter to zero
   * @returns Zero (the reset value)
   */
  reset(): number;
  
  /**
   * Get counter statistics
   * @returns Statistics object
   */
  getStats(): CounterStats;
  
  // ==========================================================================
  // Asynchronous Methods (return Promise<T>)
  // ==========================================================================
  
  /**
   * Get value with simulated network delay
   * @param delayMs - Delay in milliseconds
   * @returns Counter value after delay
   */
  getValueDelayed(args: { delayMs: number }): Promise<number>;
  
  /**
   * Perform an async add operation
   * @param value - Amount to add
   * @param delayMs - Delay in milliseconds
   * @returns Result with new value and metadata
   */
  addAsync(args: { value: number; delayMs?: number }): Promise<CounterResult>;
  
  /**
   * Divide the current value (demonstrates error handling)
   * @param divisor - Number to divide by
   * @returns Result of division
   * @throws Error if divisor is zero
   */
  divideBy(args: { divisor: number }): Promise<number>;
  
  /**
   * Fetch and apply a remote value
   * @returns The fetched remote value
   */
  fetchRemoteValue(): Promise<CounterResult>;
  
  // ==========================================================================
  // Events (use Event<T> type)
  // 
  // Events are defined as methods that return Event<PayloadType>.
  // The generator will:
  // - For Dart/TS clients: generate subscription methods returning Stream/Observable
  // - For Swift/Kotlin: generate event emission helpers
  // ==========================================================================
  
  /**
   * Emitted when the counter value changes
   */
  onCountChanged(): Event<CountChangedPayload>;
  
  /**
   * Emitted when the counter is reset
   */
  onReset(): Event<{ previousValue: number }>;
  
  /**
   * Emitted when an error occurs
   */
  onError(): Event<{ code: string; message: string }>;
}

// ============================================================================
// Event<T> Type Definition
// ============================================================================

/**
 * Event type marker - used to identify event definitions
 * The code generator recognizes this type and generates appropriate
 * subscription/emission code for each platform.
 */
export type Event<T> = {
  __eventPayload: T;
};

// ============================================================================
// Additional Example: User Service
// ============================================================================

/**
 * User information
 */
export interface User {
  id: string;
  name: string;
  email?: string;
  avatar?: string;
  createdAt: number;
}

/**
 * User preferences
 */
export interface UserPreferences {
  theme: 'light' | 'dark' | 'system';
  language: string;
  notifications: boolean;
}

/**
 * User Service
 * 
 * Manages user data and preferences.
 * 
 * @service
 * @serviceName user
 */
export interface IUserService {
  /**
   * Get current user info
   */
  getCurrentUser(): Promise<User | null>;
  
  /**
   * Update user preferences
   * @param preferences - New preferences
   */
  updatePreferences(args: { preferences: UserPreferences }): Promise<void>;
  
  /**
   * Get user preferences
   */
  getPreferences(): Promise<UserPreferences>;
  
  /**
   * User logged in event
   */
  onUserLoggedIn(): Event<User>;
  
  /**
   * User logged out event
   */
  onUserLoggedOut(): Event<{ userId: string }>;
}
