# Sample Evidence

These files are example outputs from a known-good `runmatrix.sh --all` run.
They demonstrate the expected evidence format for each cell in the interop
matrix.

## Files

| File | Cell | Verdict |
|------|------|---------|
| `baseline-go.txt` | stock-go + stock-go | PASS (cipher 1) |
| `baseline-c.txt` | stock-c + stock-c | PASS (cipher 1) |
| `baseline-jvm.txt` | stock-jvm + stock-jvm | PASS (cipher 1) |
| `neutrality-go.txt` | hookoff-go + hookoff-go | PASS (cipher 1) |
| `neutrality-c.txt` | hook-c + hook-c | PASS (cipher 1) |
| `neutrality-jvm.txt` | hook-jvm + hook-jvm | PASS (cipher 1) |
| `matched-go.txt` | hook-go + hook-go | PASS (cipher 2) |
| `mismatched-go.txt` | hook-go + hookoff-go | REJECT-AS-EXPECTED |
| `fallback-go.txt` | hook-go + stock-go | REJECT-AS-EXPECTED |
| `matrix-summary.txt` | Full matrix summary | 9/9 pass |

## Regenerating

```bash
docker compose up -d
./scripts/wait-for-ready.sh
./runmatrix.sh --all
cp evidence/*.txt examples/sample-evidence/
```
