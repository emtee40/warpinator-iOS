//
//  TransferViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit


//MARK: View Controller
final class TransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "TransferViewController:"
    
    var coordinator: RemoteCoordinator?
    
    @IBOutlet var transferDescriptionLabel: UILabel!
    
    @IBOutlet var transferProgressLabel: UILabel!
    @IBOutlet var transferStatusLabel: UILabel!
    
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var retryButton: UIButton!
    
    
    
    
    @IBOutlet var backButton: UIButton!
    
    @IBOutlet var operationsStack: UIStackView!
    
    
    var remoteViewModel: RemoteViewModel!
    var transferViewModel: TransferOperationViewModel!
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel,
         andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: "TransferViewController", bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
        
        transferViewModel.onInfoUpdated = {
            self.updateDisplay()
        }
        
        transferViewModel?.onFileAdded = {
            
        }
        
        remoteViewModel.onInfoUpdated = {
            self.updateDisplay()
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        // load intial info
        
        updateDisplay()
        
    }
    
    
    // MARK: add fileView
    private func addFileViewToStack(withViewModel viewmodel: ListedFileViewModel){
        
        let ltview = ListedFileOperationView(withViewModel: viewmodel)
        
        operationsStack.insertArrangedSubview(ltview, at: (operationsStack.arrangedSubviews.count))
        
    }
    
    
    
    // MARK: udpateDisplay
    func updateDisplay(){
        
//        retryButton.alpha = 0
//        retryButton.isUserInteractionEnabled = false
//        print(DEBUG_TAG+"updating info")
        
//        remoteViewModel.map { remoteViewModel in
//
//        }
        
        transferStatusLabel.text = "\(transferViewModel.status)"
        transferDescriptionLabel.text = transferViewModel.transferDescription + " \(remoteViewModel.displayName)"
        transferProgressLabel.text = transferViewModel.progressString
        
        // TODO: I don't like this, there's got to be a better way than
        // flicking everything off->on every update
        
        
        
        
//        cancelButton.alpha = 0
//        cancelButton.isUserInteractionEnabled = false
        
        
        
        
        
//        let buttonStatus = transferViewModel.buttonUIInfo()
        
        
        var pressable: Bool = false
        var text: String = ""
        
        switch transferViewModel.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            
            cancelButton.setTitle("Cancel", for: .normal)
            cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
            cancelButton.backgroundColor = #colorLiteral(red: 0.7831932107, green: 0.1171585075, blue: 0.006766619796, alpha: 1)
            
        case .CANCELLED, .FAILED(_):
            
            // Only allow retry if sending. Otherwise, disable button
            if transferViewModel.direction == "SENDING" {
                pressable = true
                text = "Retry"
                cancelButton.setTitle("Retry", for: .normal)
                cancelButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
                cancelButton.backgroundColor = #colorLiteral(red: 0.1902806013, green: 0.6370570039, blue: 0.2034104697, alpha: 1)

            } else {
                text = "Cancelled"
            }
        default:
//            text = "Cancelled"
            cancelButton.setTitle(text, for: .normal)
        }
        
        
        
        
        
        
//        if transferViewModel.status == .TRANSFERRING {
//            cancelButton.setTitle("Cancel", for: .normal)
//            cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
//            cancelButton.backgroundColor = #colorLiteral(red: 0.7831932107, green: 0.1171585075, blue: 0.006766619796, alpha: 1)
//        } else {
//            cancelButton.setTitle(buttonStatus.text, for: .normal)
//            cancelButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
//            cancelButton.backgroundColor = #colorLiteral(red: 0.1902806013, green: 0.6370570039, blue: 0.2034104697, alpha: 1)
//        }
        
        
        
        
//        if buttonStatus.pressable {
            
            cancelButton.alpha = pressable ? 1 : 0
            cancelButton.isUserInteractionEnabled = pressable

//        }

//        operationsStack.arrangedSubviews.forEach { subview in
//            subview.removeFromSuperview()
//        }
        
//        for viewmodel in transferViewModel.files {
//            addFileViewToStack(withViewModel: viewmodel)
//        }
        
    }
    
    
    // MARK: cancel
    @IBAction @objc func cancel(){
        coordinator?.cancelTransfer(forTransferUUID: transferViewModel!.UUID)
        updateDisplay()
    }
    
    
    // MARK: retry
    @IBAction @objc func retry(){
        coordinator?.retryTransfer(forTransferUUID: transferViewModel!.UUID)
        updateDisplay()
    }
    
    
    // MARK: back
    @IBAction @objc func back(){
        coordinator?.showRemote()
    }
}




extension TransferViewController {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        
//        let vm = ListedFileReaderViewModel(
        addFileViewToStack(withViewModel: MockListedFileReaderViewModel() )
        
    }
}






//
//MARK:  - ViewModel
class TransferOperationViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    var onFileAdded: ()->Void = {}
    
    
    //
    var UUID: UInt64 {
        return operation.UUID
    }
    
    
    //
    var fileCount: String {
        return "\(operation.fileCount)"
    }

    
    //
    var transferDescription: String {
        
        let filesCount: Int = operation.fileCount
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        
        let directionString = operation.direction == .RECEIVING ? "from" : "to"
        
        return "Transferring \(filesCountString) \(directionString)"
    }
    
    //
    var progressString: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return "\(formatter.string(fromByteCount: Int64(operation.bytesTransferred) ) )/\(formatter.string(fromByteCount: Int64(operation.totalSize) ))"
    }
    
    //
    var status: TransferStatus {
        return operation.status
    }
    
    //
    var direction: String {
        return "\(operation.direction)"
    }
    
    //
    var files: [ListedFileViewModel] {
        
        var viewModels: [ListedFileViewModel] = []
        
        (operation as? SendFileOperation)?.fileReaders.forEach {  reader in
            
            // If not a file reader, must be a folderReader.
            let vm: ListedFileViewModel
            if let fileReader = reader as? FileReader {
                vm = ListedFileReaderViewModel(fileReader)
            } else {
                vm = ListedFolderReaderViewModel( reader as! FolderReader )
            }
            
            viewModels.append(vm)
        }
        
        
        
        (operation as? ReceiveFileOperation)?.fileWriters.forEach { writer in
            
            // If not a file writer, must be a folderWriter.
            let vm: ListedFileViewModel
            if let fileWriter = writer as? FileWriter {
                vm = ListedFileWriterViewModel(fileWriter)
            } else {
                let folderWriter = writer as! FolderWriter
                vm = ListedFolderWriterViewModel(folderWriter)
            }
            
            viewModels.append(vm)
        }
        
        
        return viewModels
    }
    
    
    //
    var progress: Double {
        return operation.progress
    }
    
    
    //
    //
    init(for operation: TransferOperation) {
        self.operation = operation
        super.init()
        operation.addObserver(self)
    }
    
    
    //
    //
//    func buttonUIInfo() -> (pressable: Bool, text: String) {
//
//        var pressable: Bool = false
//        var text: String = "Finished"
//
//        switch operation.status {
//        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
//
//            pressable = true
//            text = "Cancel"
//
//        case .CANCELLED, .FAILED(_):
//
//            // Only allow retry if sending. Otherwise, disable button
//            guard operation.direction == .SENDING else {
//                text = "Cancelled"
//                fallthrough
//            }
//
//            pressable = true
//            text = "Retry"
//        default: break
//        }
//
//
//        return (pressable, text)
//    }
    
    
    //
    //
    func infoDidUpdate(){
        DispatchQueue.main.async { // update UI on main thread
            self.onInfoUpdated()
        }
    }
    
    
    //
    //
    func fileAdded() {
        DispatchQueue.main.async { // update UI on main thread
            self.onFileAdded()
        }
    }
    
    
    deinit {
        operation.removeObserver(self)
    }
}
