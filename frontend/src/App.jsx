import { useState } from 'react'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

function App () {
  const [code, setCode] = useState('')
  const [analysis, setAnalysis] = useState(null)
  const [loading, setLoading] = useState(false)

  const analyze = async () => {
    setLoading(true)
    setAnalysis(null)
    try{
      const response = await fetch(`${API_URL}/analyze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({terraform_code: code })
      })
      const data = await response.json()
      setAnalysis(data.analysis)
    } catch (err) {
      setAnalysis('Error connecting to API')
    } finally {
      setLoading(false)
  }
}

  return (
    <main style={{ fontFamily: 'system-ui', padding: '2rem', maxWidth: '800px', margin: '0 auto'}}>
      <h1>Terraform Analyzer</h1>
      <p>Paste your Terraform code below to get security, cost, and best practice analysis.</p>
      <textarea
        rows = {15}
        style = {{ width: '100%', fontFamily: 'monospace', fontSize: '14px' }}
        placeholder = "Paste your Terraform code here..."
        value = {code}
        onChange = {e => setCode(e.target.value)}
    />
    <br />
    <button onClick={analyze} disabled={loading || !code}>
      {loading ? 'Analyzing...' : 'Analyze'}
      </button>
      {analysis && (
        <div style = {{ marginTop: '2rem', whiteSpace: 'pre-wrap' }}>
          <h2>Analysis</h2>
          <pre>{analysis}</pre>
        </div>
      )} 
    </main>
  )
}

export default App

