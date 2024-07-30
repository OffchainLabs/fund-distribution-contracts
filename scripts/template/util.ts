import { JsonRpcProvider, Wallet } from 'ethers'
import { ethers as ethersv5 } from 'ethers-v5'

export type Unwrap<T> = T extends Promise<infer U> ? U : T

export function getEnv(name: string): string {
  const value = process.env[name] || ''
  if (value === '') {
    throw new Error(`Environment variable ${name} is not defined`)
  }
  return value
}

export class DoubleProvider {
  public readonly v5: ethersv5.providers.JsonRpcProvider
  public readonly v6: JsonRpcProvider
  constructor(public readonly url: string) {
    this.v5 = new ethersv5.providers.JsonRpcProvider(url)
    this.v6 = new JsonRpcProvider(url)
  }
}

export class DoubleWallet {
  public readonly doubleProvider: DoubleProvider
  public readonly v5: ethersv5.Wallet & {
    provider: ethersv5.providers.JsonRpcProvider
  }
  public readonly v6: Wallet & { provider: JsonRpcProvider }

  constructor(
    public readonly privateKey: string,
    urlOrProvider: string | DoubleProvider
  ) {
    this.doubleProvider = new DoubleProvider(
      urlOrProvider instanceof DoubleProvider
        ? urlOrProvider.url
        : urlOrProvider
    )

    this.v5 = new ethersv5.Wallet(
      privateKey,
      this.doubleProvider.v5
    ) as ethersv5.Wallet & { provider: ethersv5.providers.JsonRpcProvider }

    this.v6 = new Wallet(privateKey, this.doubleProvider.v6) as Wallet & {
      provider: JsonRpcProvider
    }
  }
}