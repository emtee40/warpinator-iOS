//
//  FileWriter.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


protocol WritesFile {
    var bytesWritten: Int { get }
    func processChunk(_ chunk: FileChunk) throws
    func close()
    func fail()
}

enum WritingError: Error {
    case FILENAME_MISMATCH
    case FILE_EXISTS, DIRECTORY_EXISTS
    case SPACE_UNAVAILABLE
    case UNDEFINED_ERROR(Error)
    
}


// MARK: FileWriter
class FileWriter: WritesFile {
    
    static var DEBUG_TAG: String = "FileWriter (static): "
    lazy var DEBUG_TAG: String = "FileWriter \(downloadName): "
    
    
    /* Name of file, as provided by init.
     We may need to rename the file, so we need to store the original,
     downloaded name, in order to remember which file chunks are ours.  */
    var downloadName: String
    var downloadRelativePath: String
    
    
    // The values that will be written to the filesystem (renaming feature)
    // Starts off as the original, downloaded name
    lazy var fileSystemName = downloadName
    var fileSystemParentPath: String
    
    
    var fileExtension: String = ""
    lazy var extensionlessFileSystemName = itemURL.deletingPathExtension().lastPathComponent

    var renameCount = 0
    var overwrite = false
    
    let baseURL = FileManager.default.extended.documentsDirectory
    var itemURL: URL {
        return baseURL.appendingPathComponent( fileSystemParentPath + "\(fileSystemName)" )
    }
    
    var fileHandle: FileHandle?
    var bytesWritten: Int = 0
    
    var observers: [ObservesFileOperation] = []
    
    
    //
    // MARK: - init
    init(withRelativePath path: String, modifiedRelativeParentPath moddedParentPath: String? = nil, overwrite: Bool){
        
        
        let pathParts = path.components(separatedBy: "/")
        
        downloadRelativePath = path
        downloadName = pathParts.last ?? "File"
        
        let parentPathParts = pathParts.dropLast()
        let parentPath = parentPathParts.isEmpty  ?  ""  :  parentPathParts.joined(separator: "/") + "/"
        fileSystemParentPath = moddedParentPath ?? parentPath
        
//        print(DEBUG_TAG+"fileSystemParentPath is \(fileSystemParentPath)")
        fileExtension = itemURL.pathExtension
        
        
        // file already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: itemURL.path) {
            
            // Rename
            if !overwrite {
                fileSystemName = rename(downloadName) + ".\(fileExtension)"
            } else { //Overwrite
                
                do {
                    print(DEBUG_TAG+"\toverwriting preexisting file")
                    try fileManager.removeItem(at: itemURL)
                } catch {
                    // if overwrite fails, rename
                    print(DEBUG_TAG+"\tfailed to overwrite, renaming...")
                    fileSystemName = rename(downloadName) + ".\(fileExtension)"
                }
            }
        }
        
        
        fileManager.createFile(atPath: itemURL.path, contents: nil)
        print(DEBUG_TAG+"created file called \( fileSystemParentPath + "\(fileSystemName)" )")
        
        fileHandle = try? FileHandle(forUpdating: itemURL)
    }
    
    
    
    //
    // MARK: rename file
    // TODO: rewrite to be gooder?
    private func rename(_ name: String) -> String {
        
        var newName = "File_Renaming_Failed"
        
        //
        // 1000 is probably enough,
        // rihgt?
        while renameCount <= 1000 {
            renameCount += 1
            
            print(DEBUG_TAG+"Renaming \(name) (attempt: \(renameCount))")
            
            let nameCheck = extensionlessFileSystemName + "\(renameCount)"
            let path = baseURL.path + "/" + fileSystemParentPath + "\(nameCheck)" + "." + fileExtension
            
            if !FileManager.default.fileExists(atPath: path)  {
                print(DEBUG_TAG+"\t\t \"\(nameCheck).\(fileExtension) not found at path: \n\t\t \(path)")
                print(DEBUG_TAG+"\t\t proceeding... ")
                newName = nameCheck
                break
            }
        }
        
        print(DEBUG_TAG+"\tnew name:  \(newName)")
        return newName
    }
    
    
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk) throws {
        
        
        defer {
            updateObserversInfo()
        }
        
        // Check if chunk belongs with current file
        guard chunk.relativePath == downloadRelativePath else {
            throw WritingError.FILENAME_MISMATCH
        }
        
        
        guard let handle = fileHandle else {
            print(DEBUG_TAG+"UnexpectedError: fileHandle not found?")
            return
        }
        
        let data = chunk.chunk
        
        handle.seekToEndOfFile()
        handle.write(data)
        
        bytesWritten += data.count
        
    }
    
    
    // MARK: close
    func close(){
        fileHandle?.closeFile()
        fileHandle = nil
        updateObserversInfo()
    }
    
    
    // MARK: fail
    func fail(){
        print(DEBUG_TAG+"\tfailing filewrite")
        guard fileHandle != nil else { return  }
        
        close()

        // delete unfinished file
        do {
            try FileManager.default.removeItem(at: itemURL)
        } catch {  print(DEBUG_TAG+"\tAn error occurred attempting to delete file: \(itemURL.path)") }
    }
    
}


//MARK: observers
extension FileWriter {
    
    func addObserver(_ model: ObservesFileOperation){
        observers.append(model)
    }
    
    func removeObserver(_ model: ObservesFileOperation){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func updateObserversInfo(){
        observers.forEach { observer in
            observer.infoDidUpdate()  
        }
    }
}

