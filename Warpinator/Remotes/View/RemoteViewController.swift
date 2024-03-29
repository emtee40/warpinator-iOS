//
//  RemoteViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-18.
//

import UIKit


//MARK: View Controller
final class RemoteViewController: UIViewController {

    
    var coordinator: RemoteCoordinator?
    
    @IBOutlet var avatarImageView: UIImageView!
    
    @IBOutlet var displayNameLabel: UILabel!
    
    @IBOutlet var deviceNameLabel: UILabel!
    
    @IBOutlet var ipaddressLabel: UILabel!
    
    @IBOutlet var statusLabel: UILabel!
    
    
    @IBOutlet var transfersStack: UIStackView!
    
    @IBOutlet var backButton: UIButton!
    
    @IBOutlet var sendFilesButton: UIButton!
    
    var viewModel: RemoteViewModel?
    
    
    init(withViewModel viewModel: RemoteViewModel) {
        super.init(nibName: "RemoteViewController",
                   bundle: Bundle(for: type(of: self)))
        
        
        self.viewModel = viewModel
        
        
        self.viewModel!.onInfoUpdated = { [weak self] in
            self?.updateDisplay()
        }
        
        self.viewModel!.onTransferAdded = { [weak self] viewmodel in
            self?.addTransferViewToStack(withViewModel: viewmodel)
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    //
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        // removing intial IB view
        for view in transfersStack.arrangedSubviews {   view.removeFromSuperview()
        }
        
        
        // load intial info
        updateDisplay()
        
        for transfer_viewmodel in self.viewModel!.transfers {
            addTransferViewToStack(withViewModel: transfer_viewmodel)
        }
        
        avatarImageView.image = viewModel?.avatarImage ?? UIImage(systemName: "person.fill",
                                                                   compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
        
    }
    
    
    //
    // MARK: updateDisplay
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        // grab existing attributes of each label to pass on to the next attributed string
        var attrs = displayNameLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        displayNameLabel.attributedText = viewModel.displayName.extended.attributed(attrs)
        
        attrs = deviceNameLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        deviceNameLabel.attributedText = viewModel.deviceName.extended.attributed(attrs)
        
        attrs = ipaddressLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        ipaddressLabel.attributedText = viewModel.iNetAddress.extended.attributed(attrs)
        
        attrs = statusLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        statusLabel.attributedText = viewModel.status.extended.attributed( attrs )
        
//        displayNameLabel.attributedText = displayNameString
//        deviceNameLabel.attributedText = usernameString
//        ipaddressLabel.attributedText = ipString
        
//        statusLabel.attributedText = statusString
        
        
        if let image = viewModel.avatarImage {
            self.avatarImageView.image = image
            self.view.setNeedsLayout()
        }
        
    }
    
    
    //
    // MARK: addTransferViewToStack
    private func addTransferViewToStack(withViewModel viewmodel: ListedTransferViewModel){
        let ltview = ListedTransferView(withViewModel: viewmodel, onTap: {
            self.coordinator?.userSelectedTransfer(withUUID: viewmodel.UUID )
        })
        transfersStack.insertArrangedSubview(ltview, at: (transfersStack.arrangedSubviews.count))
    }
    
    
    
    //
    // MARK: sendFiles
    @IBAction @objc func sendFiles(){
        
        coordinator?.createTransfer()
    }
    
    
    //
    // MARK: back
    @IBAction @objc func back(){
        coordinator?.back()
    }
}






//
// MARK: ViewModel
final class RemoteViewModel: NSObject, ObservesRemote {
    
    private var remote: Remote
    
    var onInfoUpdated: ()->Void = {}
    var onTransferAdded: (ListedTransferViewModel) -> Void = { viewmodel in }
    
    var avatarImage: UIImage? {
        return remote.details.userImage
    }
    
    var displayName: String {
        return remote.details.displayName
    }
    
    var deviceName: String {
        return remote.details.username + "@" + remote.details.hostname
    }
    
    var iNetAddress: String {
        return remote.details.ipAddress
    }
    
    var hostname: String {
        return remote.details.hostname
    }
    
    var status: String {
        return remote.details.status.rawValue
    }
    
    
    var transfers: [ListedTransferViewModel] {

        var viewmodels:[ListedTransferViewModel] = []
        let operations: [TransferOperation] = remote.sendingOperations + remote.receivingOperations

        for operation in operations  {
            viewmodels.append( ListedTransferViewModel(for: operation) )
        }

        return viewmodels
    }
    
    
    init(_ remote: Remote) {
        self.remote = remote
        super.init()
        
        remote.addObserver(self)
    }
    
    
    func infoDidUpdate(){
        DispatchQueue.main.async { // execute UI on main thread
            self.onInfoUpdated()
        }
    }
    
    func operationAdded(_ operation: TransferOperation){
        DispatchQueue.main.async { // execute UI on main thread
            self.onTransferAdded(ListedTransferViewModel(for: operation))
        }
    }
    
    deinit {
        remote.removeObserver(self)
    }
}







//
// MARK: Interface Builder
extension RemoteViewController {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
    }
}
