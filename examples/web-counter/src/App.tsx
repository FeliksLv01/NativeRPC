import { useEffect, useState } from 'react'
import { NativeRPC } from '@token-team/nativerpc-web'

const styles = {
  container: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    maxWidth: 400,
    margin: '0 auto',
    padding: 20,
    textAlign: 'center' as const,
  },
  header: {
    marginBottom: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold' as const,
    marginBottom: 8,
  },
  status: {
    display: 'inline-block',
    padding: '4px 12px',
    borderRadius: 12,
    fontSize: 14,
    fontWeight: 500,
  },
  statusConnected: {
    backgroundColor: '#d4edda',
    color: '#155724',
  },
  statusError: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
  },
  statusConnecting: {
    backgroundColor: '#fff3cd',
    color: '#856404',
  },
  counterDisplay: {
    marginBottom: 24,
  },
  counterLabel: {
    fontSize: 16,
    color: '#666',
    marginBottom: 8,
  },
  counterValue: {
    fontSize: 64,
    fontWeight: 'bold' as const,
    color: '#6200ee',
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: 'bold' as const,
    color: '#666',
    marginBottom: 12,
  },
  buttonRow: {
    display: 'flex',
    gap: 8,
    justifyContent: 'center',
    flexWrap: 'wrap' as const,
    marginBottom: 8,
  },
  button: {
    padding: '10px 20px',
    fontSize: 16,
    borderRadius: 8,
    border: 'none',
    cursor: 'pointer',
    backgroundColor: '#6200ee',
    color: 'white',
  },
  buttonOutline: {
    padding: '10px 20px',
    fontSize: 16,
    borderRadius: 8,
    border: '2px solid #6200ee',
    cursor: 'pointer',
    backgroundColor: 'transparent',
    color: '#6200ee',
  },
  buttonDisabled: {
    opacity: 0.5,
    cursor: 'not-allowed',
  },
  resultBox: {
    marginTop: 16,
    padding: 16,
    backgroundColor: '#e3f2fd',
    borderRadius: 8,
    textAlign: 'left' as const,
  },
  errorBox: {
    marginTop: 16,
    padding: 16,
    backgroundColor: '#ffebee',
    borderRadius: 8,
    color: '#c62828',
    textAlign: 'left' as const,
  },
}

type Status = 'connecting' | 'connected' | 'error'

interface CountChangedData {
  count: number
}

export default function App() {
  const [count, setCount] = useState(0)
  const [status, setStatus] = useState<Status>('connecting')
  const [error, setError] = useState<string | null>(null)
  const [asyncResult, setAsyncResult] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    initializeRPC()
    return () => {
      NativeRPC.dispose()
    }
  }, [])

  async function initializeRPC() {
    try {
      // Wait for native bridge to be ready
      await NativeRPC.ready(5000)

      // Initialize with debug logging
      NativeRPC.init({ debug: true })

      // Subscribe to count changed events
      NativeRPC.on<CountChangedData>('counter.countChanged', (data) => {
        console.log('[Web] Count changed:', data)
        setCount(data.count)
      })

      // Get initial value
      const value = await NativeRPC.call<number>('counter.getValue')
      setCount(value)
      setStatus('connected')
      setError(null)
    } catch (e) {
      console.error('[Web] Init error:', e)
      setStatus('error')
      setError(e instanceof Error ? e.message : String(e))
    }
  }

  async function handleIncrement() {
    try {
      const newValue = await NativeRPC.call<number>('counter.increment')
      setCount(newValue)
      setError(null)
    } catch (e) {
      setError(`increment failed: ${e}`)
    }
  }

  async function handleDecrement() {
    try {
      const newValue = await NativeRPC.call<number>('counter.decrement')
      setCount(newValue)
      setError(null)
    } catch (e) {
      setError(`decrement failed: ${e}`)
    }
  }

  async function handleAdd(value: number) {
    try {
      const newValue = await NativeRPC.call<number>('counter.add', { value })
      setCount(newValue)
      setError(null)
    } catch (e) {
      setError(`add failed: ${e}`)
    }
  }

  async function handleAddTwo(a: number, b: number) {
    try {
      const newValue = await NativeRPC.call<number>('counter.addTwo', { a, b })
      setCount(newValue)
      setError(null)
      setAsyncResult(`addTwo(${a}, ${b}) = ${a} + ${b} = ${a + b}, new count: ${newValue}`)
    } catch (e) {
      setError(`addTwo failed: ${e}`)
    }
  }

  async function handleReset() {
    try {
      const newValue = await NativeRPC.call<number>('counter.reset')
      setCount(newValue)
      setError(null)
    } catch (e) {
      setError(`reset failed: ${e}`)
    }
  }

  async function handleGetValueDelayed() {
    setIsLoading(true)
    setAsyncResult(null)
    setError(null)

    try {
      const start = Date.now()
      const value = await NativeRPC.call<number>('counter.getValueDelayed', { delayMs: 1000 })
      const elapsed = Date.now() - start
      setAsyncResult(`getValueDelayed: ${value} (took ${elapsed}ms)`)
    } catch (e) {
      setError(`getValueDelayed failed: ${e}`)
    } finally {
      setIsLoading(false)
    }
  }

  async function handleDivideBy(divisor: number) {
    setIsLoading(true)
    setAsyncResult(null)
    setError(null)

    try {
      const result = await NativeRPC.call<number>('counter.divideBy', { divisor })
      setAsyncResult(`divideBy(${divisor}): ${count} / ${divisor} = ${result}`)
    } catch (e) {
      setError(`divideBy(${divisor}) failed: ${e}`)
    } finally {
      setIsLoading(false)
    }
  }

  const getStatusStyle = () => {
    switch (status) {
      case 'connected':
        return { ...styles.status, ...styles.statusConnected }
      case 'error':
        return { ...styles.status, ...styles.statusError }
      default:
        return { ...styles.status, ...styles.statusConnecting }
    }
  }

  const statusText = status === 'connected' ? 'Connected' : status === 'error' ? 'Error' : 'Connecting...'

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <div style={styles.title}>NativeRPC Web Counter</div>
        <span style={getStatusStyle()}>Status: {statusText}</span>
      </div>

      {/* Counter Display */}
      <div style={styles.counterDisplay}>
        <div style={styles.counterLabel}>Counter Value:</div>
        <div style={styles.counterValue}>{count}</div>
      </div>

      {/* Sync Functions */}
      <div style={styles.section}>
        <div style={styles.sectionTitle}>Sync Functions</div>
        <div style={styles.buttonRow}>
          <button style={styles.button} onClick={handleDecrement}>
            − Decrement
          </button>
          <button style={styles.button} onClick={handleIncrement}>
            + Increment
          </button>
        </div>
        <div style={styles.buttonRow}>
          <button style={styles.buttonOutline} onClick={() => handleAdd(5)}>
            Add 5
          </button>
          <button style={styles.buttonOutline} onClick={() => handleAdd(10)}>
            Add 10
          </button>
          <button style={styles.buttonOutline} onClick={handleReset}>
            Reset
          </button>
        </div>
        <div style={styles.buttonRow}>
          <button style={{ ...styles.buttonOutline, borderColor: '#4caf50', color: '#4caf50' }} onClick={() => handleAddTwo(3, 7)}>
            AddTwo(3, 7)
          </button>
          <button style={{ ...styles.buttonOutline, borderColor: '#4caf50', color: '#4caf50' }} onClick={() => handleAddTwo(10, 20)}>
            AddTwo(10, 20)
          </button>
        </div>
      </div>

      {/* Async Functions */}
      <div style={styles.section}>
        <div style={styles.sectionTitle}>Async Functions</div>
        <div style={styles.buttonRow}>
          <button
            style={{ ...styles.buttonOutline, ...(isLoading ? styles.buttonDisabled : {}) }}
            onClick={handleGetValueDelayed}
            disabled={isLoading}
          >
            getValueDelayed (1s)
          </button>
        </div>
        <div style={styles.buttonRow}>
          <button
            style={{ ...styles.buttonOutline, ...(isLoading ? styles.buttonDisabled : {}) }}
            onClick={() => handleDivideBy(2)}
            disabled={isLoading}
          >
            divideBy(2)
          </button>
          <button
            style={{
              ...styles.buttonOutline,
              borderColor: '#ff9800',
              color: '#ff9800',
              ...(isLoading ? styles.buttonDisabled : {}),
            }}
            onClick={() => handleDivideBy(0)}
            disabled={isLoading}
          >
            divideBy(0) - Error
          </button>
        </div>
      </div>

      {/* Async Result */}
      {asyncResult && (
        <div style={styles.resultBox}>
          <strong>Async Result:</strong>
          <br />
          {asyncResult}
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div style={styles.errorBox}>
          <strong>Error:</strong>
          <br />
          {error}
        </div>
      )}
    </div>
  )
}
