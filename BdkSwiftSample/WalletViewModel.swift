//
//  WalletViewModel.swift
//  IOSBdkAppSample
//
//  Created by Sudarsan Balaji on 29/10/21.
//

import Foundation
import BitcoinDevKit

extension TransactionDetails: Comparable {
    public static func < (lhs: TransactionDetails, rhs: TransactionDetails) -> Bool {
        
        let lhs_timestamp: UInt64 = lhs.confirmationTime?.timestamp ?? UInt64.max;
        let rhs_timestamp: UInt64 = rhs.confirmationTime?.timestamp ?? UInt64.max;
        
        return lhs_timestamp < rhs_timestamp
    }
}

class WalletViewModel: ObservableObject {
    enum State {
        case empty
        case loading
        case failed(Error)
        case loaded(Wallet, Blockchain)
    }
    
    enum SyncState {
        case empty
        case syncing
        case synced
        case failed(Error)
    }
    
    private(set) var key = "private_key"
    @Published private(set) var state = State.empty
    @Published private(set) var syncState = SyncState.empty
    @Published private(set) var balance: UInt64 = 0
    @Published private(set) var balanceText = "sync plz"
    @Published private(set) var transactions: [BitcoinDevKit.TransactionDetails] = []
    
    func load() {
        state = .loading
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            let db = DatabaseConfig.memory
            do {
            let descriptor = try Descriptor.init(descriptor: "wpkh(tprv8ZgxMBicQKsPeSitUfdxhsVaf4BXAASVAbHypn2jnPcjmQZvqZYkeqx7EHQTWvdubTSDa5ben7zHC7sUsx4d8tbTvWdUtHzR8uhHg2CW7MT/*)", network: Network.testnet)
            let electrum = ElectrumConfig(url: "ssl://electrum.blockstream.info:60002", socks5: nil, retry: 5, timeout: nil, stopGap: 10, validateDomain: true)
            let blockchainConfig = BlockchainConfig.electrum(config: electrum)
                let blockchain = try Blockchain(config: blockchainConfig)
                let wallet = try Wallet(descriptor: descriptor, changeDescriptor: nil, network: Network.testnet, databaseConfig: db)
                
                DispatchQueue.main.async {
                    self.state = State.loaded(wallet, blockchain)
                }
            } catch let error {
                DispatchQueue.main.async {
                    self.state = State.failed(error)
                }
            }
        }
    }
    
    func sync() {
        self.balanceText = "syncing"
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            switch self.state {
            case .loaded(let wallet, let blockchain):
                DispatchQueue.main.async {
                    self.syncState = .syncing
                }
                do {
                    // TODO use this progress update to show "syncing"
                    try wallet.sync(blockchain: blockchain, progress: nil)
                    let balance = try wallet.getBalance().confirmed
                    let wallet_transactions: [TransactionDetails] = try wallet.listTransactions()

                    DispatchQueue.main.async {
                        self.syncState = .synced
                        self.balance = balance
                        self.balanceText = String(format: "%.8f", Double(self.balance) / Double(100000000))
                        self.transactions = wallet_transactions.sorted().reversed()
                    }
              } catch let error {
                  print(error)
                  DispatchQueue.main.async {
                      self.syncState = .failed(error)
                  }
              }
            default: do { }
                print("default")
            }
        }
    }
}
