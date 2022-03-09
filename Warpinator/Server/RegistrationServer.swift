//
//  RegistrationServer.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-01.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network

import Logging


// MARK: - Registration Server
final class RegistrationServer {
    
    private let DEBUG_TAG: String = "RegistrationServer: "
    
    var mDNSBrowser: MDNSBrowser?
    var mDNSListener: MDNSListener?
    
//    var certificateServer = CertificateServer()
    
    var eventLoopGroup: EventLoopGroup?

    private lazy var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    var remoteManager: RemoteManager?
//    {
//        didSet {  warpinatorRegistrationProvider.remoteManager = remoteManager  }
//    }
    
    var settingsManager: SettingsManager
    
    var server : GRPC.Server?
    
    let queueLabel = "RegistrationServerQueue"
    lazy var serverQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)

    
    init(settingsManager manager: SettingsManager) {
        settingsManager = manager
//        warpinatorRegistrationProvider.settingsManager = settingsManager
    }
    
    
    //
    // MARK: start
    func start(){
        
        guard let registrationServerELG = eventLoopGroup else { return }
        
        let portNumber = Int( settingsManager.registrationPortNumber )
        
        GRPC.Server.insecure(group: registrationServerELG)
            .withServiceProviders([warpinatorRegistrationProvider])
            .bind(host: "\(Utils.getIP_V4_Address())", port: portNumber).whenSuccess { server in
                
                print(self.DEBUG_TAG+"registration server started on: \(String(describing: server.channel.localAddress))")
                
                self.server = server
                self.startMDNSServices()
                
            }
    }
    
    
    
    //
    // MARK: stop
    func stop() -> EventLoopFuture<Void>? {
        
        guard let server = server else {
            return eventLoopGroup?.next().makeSucceededVoidFuture()
        }
        
        mDNSListener?.stop()
        mDNSBrowser?.stop()
        
        return server.initiateGracefulShutdown()
    }
    
    
    //
    // MARK:  startMDNSServices
    private func startMDNSServices(){
        print(DEBUG_TAG+"Starting MDNS services...")
        mDNSBrowser = MDNSBrowser()
        mDNSBrowser?.delegate = self
        
        mDNSListener = MDNSListener(settingsManager: settingsManager)
        mDNSListener?.delegate = self
        mDNSListener?.settingsManager = settingsManager
        mDNSListener?.start()
        
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
//            print(self.DEBUG_TAG+"RESTARTING IN  15...")
//            self.mDNSBrowser?.restart()
//        }
        
    }
    
    
    //
    // MARK: stop mDNS
    private func stopMDNSServices(){
        mDNSBrowser?.stop()
        mDNSListener?.stop()
    }
    
    
    
    
    func mockStart(){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print(self.DEBUG_TAG+"mocking registration")
            self.mockRegistration()
        }
    }
    
    

}



//
// MARK: - MDNSListenerDelegate
extension RegistrationServer: MDNSListenerDelegate {
    func mDNSListenerIsReady() {
        mDNSBrowser?.start()
    }
}



//
// MARK: - MDNSBrowserDelegate
extension RegistrationServer: MDNSBrowserDelegate {
    
    
    
    // MARK: didAddResult
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        
        
        print(DEBUG_TAG+"mDNSBrowser added result:")
        print(DEBUG_TAG+"\t\(result.endpoint)")
        
        // if the metadata has a record "type",
        // and if type is 'flush', then ignore this service
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type == "flush" {
            print(DEBUG_TAG+"service \(result.endpoint) is flushing; ignore"); return
        }
        print(DEBUG_TAG+"assuming service is real, continuing...")
        print(DEBUG_TAG+"\tmetadata: \(result.metadata)")
        
        
        var serviceName = "unknown_service"
        switch result.endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            
            print(DEBUG_TAG+"Found service \(name) (at endpoint: \(result.endpoint))")
            
            serviceName = name
            
            // Check if we found own MDNS record
            if name == settingsManager.uuid {
                print(DEBUG_TAG+"\t\tFound myself (\(result.endpoint))"); return
            } else {
                print(DEBUG_TAG+"service discovered: \(name)")
            }
            
        default: print(DEBUG_TAG+"unknown service endpoint type: \(result.endpoint)"); return
        }
        
        
        //
        var hostname = serviceName
        var api = "1"
        var authPort = 42000
        
        // parse TXT record for metadata
        if case let NWBrowser.Result.Metadata.bonjour(txtRecord) = result.metadata {
            
            for (key, value) in txtRecord.dictionary {
                switch key {
                case "hostname": hostname = value
                case "api-version": api = value
                case "auth-port": authPort = Int(value) ?? 42000
                default: print("unknown TXT record type: \(key)-\(value)")
                }
            }
        }
        
        
        
        // check if we already know this remote
        if let remote = remoteManager?.containsRemote(for: serviceName) {
            
            print(DEBUG_TAG+"Service already added")
            
            // Are we connected?
            if [ .Disconnected, .Idle, .Error ].contains(remote.details.status ) {
                print(DEBUG_TAG+"\t\t not connected: reconnecting...")
                remote.startConnection()
            }
            return
        }
        
        
        var details = RemoteDetails(endpoint: result.endpoint)
        details.hostname = hostname
        details.uuid = serviceName
        details.api = api
        details.port = 42000
        details.authPort = authPort //"42000"
        details.status = .Disconnected
        
        
        let newRemote = Remote(details: details)
        
        remoteManager?.addRemote(newRemote)
    }

}



//MARK: - Mock Registration
extension RegistrationServer {
    func mockRegistration(){
        
        for i in 0...5 {
            
            var mockDetails = RemoteDetails.MOCK_DETAILS
            mockDetails.uuid = mockDetails.uuid + "__\(i)"
            
            let mockRemote = Remote(details: mockDetails)
            
            remoteManager?.addRemote(mockRemote)
        }
        
    }
}