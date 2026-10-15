// copied from https://github.com/godzillaba/eth-cli/blob/05e9d392797b1759745e4e84e3c4c51cf4514c31/src/utils/get-logs.ts
import type { providers } from 'ethers-v5'

// Try the whole range in one request; on a JSON-RPC error, split in half and
// recurse. Network and other errors rethrow, as does a single-block failure
// (which can't be a size problem).
export async function getLogsPaginated(
  provider: providers.JsonRpcProvider,
  filter: providers.Filter
): Promise<providers.Log[]> {
  const from = typeof filter.fromBlock === 'number' ? filter.fromBlock : 0
  const to =
    typeof filter.toBlock === 'number'
      ? filter.toBlock
      : await provider.getBlockNumber()
  return getRange(provider, filter, from, to)
}

async function getRange(
  provider: providers.JsonRpcProvider,
  filter: providers.Filter,
  from: number,
  to: number
): Promise<providers.Log[]> {
  try {
    return await provider.getLogs({ ...filter, fromBlock: from, toBlock: to })
  } catch (err) {
    if (from >= to || !isJsonRpcError(err)) throw err
    const mid = Math.floor((from + to) / 2)
    return [
      ...(await getRange(provider, filter, from, mid)),
      ...(await getRange(provider, filter, mid + 1, to)),
    ]
  }
}

// A JSON-RPC error response carries a numeric code, either directly on the
// error (websocket/batch providers) or on the nested .error of the ethers v5
// SERVER_ERROR wrapper (http providers). Transport failures never have one.
function isJsonRpcError(err: unknown): boolean {
  const e = err as { code?: unknown; error?: { code?: unknown } }
  return typeof e?.code === 'number' || typeof e?.error?.code === 'number'
}
