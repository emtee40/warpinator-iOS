//
//  MDNSListener.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-15.
//

import Foundation

import NIO

import Network

import NIOSSL
import CryptoKit
import Sodium


protocol MDNSListenerDelegate: AnyObject {
    func mDNSListenerIsReady()
}

final class MDNSListener {
    
    enum ServiceError: Error {
        case CANCELLED
        case ALREADY_RUNNING
        case UNKNOWN_SERVICE
    }
    
    private let DEBUG_TAG = "MDNSListener: "
    
     let SERVICE_TYPE = "_warpinator._tcp"
     let SERVICE_DOMAIN = ""
    
    var displayName: String = SettingsManager.shared.displayName
    
    var connections: [NWEndpoint : NWConnection] = [:]
    
    var flushing = false
    
    var certificateServer = CertificateServer()
    
    
    var parameters: NWParameters {
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return params
    }
    
    var port: NWEndpoint.Port {
        let transferPortNum =  UInt16( SettingsManager.shared.transferPortNumber)
        return NWEndpoint.Port(rawValue: transferPortNum)!
    }
    
    
    lazy var listener: NWListener = createListener()
    
    var eventloopGroup: EventLoopGroup?
    
    weak var delegate: MDNSListenerDelegate?
    
    let queueLabel = "MDNSListenerQueue"
    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init(withEventloopGroup group: EventLoopGroup) {

        eventloopGroup = group
        
//        listener.stateUpdateHandler stateDidUpdate(state:)
//        stopListening()
//        listener.start(queue: listenerQueue )
    }
    
    
    private func createListener() -> NWListener {
        
        print(DEBUG_TAG+"\t Creating listener")
        return try! NWListener(using: parameters, on: port )
    }
    
    
    
    //
    // MARK: start
    func start() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+" starting... (current state:  \(listener.state) )")
        
        let onReadyPromise = eventloopGroup!.next().makePromise(of: Void.self)
        
        guard listener.state != .ready else {
            onReadyPromise.fail( ServiceError.ALREADY_RUNNING )
            return onReadyPromise.futureResult
        }
        
        configurePromiseOnReady(onReadyPromise)
        stopListening() // listener requires a connection handler, this just sets it (to one that rejects everything)
        
        listener.start(queue: listenerQueue )
        
        return onReadyPromise.futureResult
    }
    
    
    
    //
    // MARK: stop
    func stop() -> EventLoopFuture<Void> {
        
        let onStopPromise = eventloopGroup!.next().makePromise(of: Void.self)
        
        switch listener.state {
        case .cancelled, .failed(_):  onStopPromise.succeed( {}() )
        default:
            configurePromiseOnStopped(onStopPromise)
            listener.cancel()
        }
        
        return onStopPromise.futureResult
    }
    
    
    
    //
    //
    private func configurePromiseOnReady(_ promise: EventLoopPromise<Void>) {
        
        listener.stateUpdateHandler = { state in
            print(self.DEBUG_TAG+"\t\tstate is \(state)")
            switch state {
            case .setup: return
            case .ready:
                promise.succeed( {}() )
            case .failed(let error): fallthrough
            case .waiting(let error): promise.fail(error)
            case .cancelled: promise.fail( MDNSListener.ServiceError.CANCELLED )
            @unknown default:
                promise.fail( MDNSListener.ServiceError.UNKNOWN_SERVICE )
            }
            
            self.listener.stateUpdateHandler = self.stateDidUpdate(state: )
        }
    }
    
    
    
    //
    //
    private func configurePromiseOnStopped(_ onStopPromise: EventLoopPromise<Void>) {
        
        listener.stateUpdateHandler = { state in
            print(self.DEBUG_TAG+"\t\tstate is \(state)")
            switch state {
//            case .setup, .ready, .waiting(_):
            case .failed(_): fallthrough
            case .cancelled: onStopPromise.succeed( {}() )
            default:
                self.stopListening()
                self.listener.cancel()
                return
            }
            
            self.listener.stateUpdateHandler = self.stateDidUpdate(state: )
        }
    }
    
    
    
    
    //
    // MARK: start listening
    func startListening(){
        print(DEBUG_TAG+"start listening")
        listener.newConnectionHandler = newConnectionEstablished(newConnection:)
    }
    
    
    //
    // MARK: stop listening
    func stopListening(){
        print(DEBUG_TAG+"stop listening")
        listener.newConnectionHandler = { $0.cancel() }
    }
    
    
    //
    // MARK: publishService
    func publishService(){
        
        print(DEBUG_TAG+"\tpublishing for reals...")
        
        guard listener.state == .ready else {
            print(DEBUG_TAG+"\tlistener is not ready (\(listener.state))")
            return
        }
        
        stopListening()
        
        flushing = false
        
        let hostname = SettingsManager.shared.hostname
        let authport = SettingsManager.shared.registrationPortNumber
        let uuid = SettingsManager.shared.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "auth-port" : "\(authport)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        
        listener.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        
        
        startListening()
        
        delegate?.mDNSListenerIsReady()
    }
    
    
    //
    // MARK: flushPublish
    func flushPublish(){

        
        guard listener.state == .ready  else {
            print(DEBUG_TAG+"\tlistener is not ready (\(listener.state))")
            return
        }
        
        
        stopListening()
        
        print(DEBUG_TAG+"\tFlushing...")
        flushing = true

        
        let hostname = SettingsManager.shared.hostname
        let uuid = SettingsManager.shared.uuid

        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "type" : "flush"]
        
        listener.service = NWListener.Service(name: uuid,
                                              type: SERVICE_TYPE,
                                              domain: SERVICE_DOMAIN,
                                              txtRecord:  NWTXTRecord(properties) )
        
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.listener.service = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.publishService()
            }
        }
    }
    
    
    func removeService() {
        listener.service = nil
    }
    
    
    
    //
    // MARK: stateDidUpdate
    private func stateDidUpdate(state: NWListener.State ) {
        
        print(DEBUG_TAG+" state updated -> \(state)")
        
        switch state {
        case .cancelled:  print(DEBUG_TAG+" cancelled")
        
        case .failed(let error):
            print(DEBUG_TAG+"listener failed; error: \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                restartListener()
                return
                
            } else {    print(DEBUG_TAG+"\t\tstopping")     }
            
            listener.cancel()
            
        default: break //print(DEBUG_TAG+"State updated: \(state)")
        }
    }
    
    
    private func restartStateHandler(state: NWListener.State ) {
        
        print(DEBUG_TAG+" restart state changed (\(state))")
        
        switch state {
            
        case .cancelled:
            
            listener = createListener()
            listener.stateUpdateHandler = restartStateHandler(state:)
            stopListening()
            listener.start(queue: listenerQueue)
        
        case .ready:
            listener.stateUpdateHandler = stateDidUpdate(state:)
            flushPublish()
            
        case .failed(let error) :
            
            print(DEBUG_TAG+"listener failed; error: \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                
                listenerQueue.asyncAfter(deadline: .now() + 1) {
                    self.restartListener()
                }
                return
                
            } else {
                print(DEBUG_TAG+"\t\tstopping")
            }
            
            listener.cancel()
            
        default: print(DEBUG_TAG+" state: \(state)")
            
        }
    }
    
    
    
    //
    // MARK: restart
    func restartListener(){
        
        print(DEBUG_TAG+"\t\t restarting")
        
        listener.stateUpdateHandler = restartStateHandler(state: )
        
        listener.cancel()
    }
    
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
//        print(DEBUG_TAG+"new connection: \n\t\(connection)")
        
        // TODO: I feel like the meat of this function belongs in CertificateServer itself.
        // ie. Receive new connection -> pass it straight along to certificateServer
        
        connection.parameters.allowLocalEndpointReuse = true
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            
//            print((self?.DEBUG_TAG ?? "(MDNSListener is nil): ")+"\(connection.endpoint) updated state: \(state)")
            
            switch state {
            case .ready:
                
                // serve certificate as soon as connection is ready
                self?.certificateServer.serveCertificate(to: connection) {
                    connection.cancel() // cancel when finished
                }
            case .cancelled, .failed(_):
                
                // remove connection when cancelled or failed
                self?.connections.removeValue(forKey: connection.endpoint)
            default: break
                
            }
            
        }
        
        connection.start(queue: .main)
    }
}
