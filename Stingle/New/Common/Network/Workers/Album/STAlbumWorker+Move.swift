//
//  STAlbumWorker+Move.swift
//  Stingle
//
//  Created by Khoren Asatryan on 5/9/21.
//

import Foundation

extension STAlbumWorker {
    
    func moveFiles(fromAlbum: STLibrary.Album, toAlbum: STLibrary.Album, files: [STLibrary.AlbumFile], isMoving: Bool, reloadDBData: Bool = true, success: Success<STEmptyResponse>?, failure: Failure?) {
        
        let files = files.filter({ $0.isRemote == true })
        guard !files.isEmpty else {
            success?(STEmptyResponse())
            return
        }
        
        let crypto = STApplication.shared.crypto
        let albumFilesProvider = STApplication.shared.dataBase.albumFilesProvider
        let albumsProvider = STApplication.shared.dataBase.albumsProvider
        var newHeaders = [String: String]()
        
        do {
            let fromAlbumData = try crypto.decryptAlbum(albumPKStr: fromAlbum.publicKey, encAlbumSKStr: fromAlbum.encPrivateKey, metadataStr: fromAlbum.metadata)
            var newAlbumFiles = [STLibrary.AlbumFile]()
            for file in files {
                guard let publicKey = crypto.base64ToByte(encodedStr: toAlbum.publicKey) else {
                    failure?(WorkerError.emptyData)
                    return
                }
                let newHeader = try crypto.reencryptFileHeaders(headersStr: file.headers, publicKeyTo: publicKey, privateKeyFrom: fromAlbumData.privateKey, publicKeyFrom: fromAlbumData.publicKey)
                newHeaders[file.file] = newHeader
                let newAlbumFile = try STLibrary.AlbumFile(file: file.file,
                                                       version: file.version,
                                                       headers: newHeader,
                                                       dateCreated: file.dateCreated,
                                                       dateModified: Date(),
                                                       isRemote: file.isRemote,
                                                       albumId: toAlbum.albumId)
                newAlbumFiles.append(newAlbumFile)
            }
            
            let request = STAlbumRequest.moveFile(fromSet: .album, toSet: .album, albumIdFrom: fromAlbum.albumId, albumIdTo: toAlbum.albumId, isMoving: isMoving, headers: newHeaders, files: files)
            self.request(request: request, success: { (response: STEmptyResponse) in
                if isMoving {
                    albumFilesProvider.delete(models: files, reloadData: reloadDBData)
                }
                let updatedAlbum = STLibrary.Album(albumId: toAlbum.albumId,
                                                   encPrivateKey: toAlbum.encPrivateKey,
                                                   publicKey: toAlbum.publicKey,
                                                   metadata: toAlbum.metadata,
                                                   isShared: toAlbum.isShared,
                                                   isHidden: toAlbum.isHidden,
                                                   isOwner: toAlbum.isOwner,
                                                   isLocked: toAlbum.isLocked,
                                                   isRemote: toAlbum.isRemote,
                                                   permissions: toAlbum.permissions,
                                                   members: toAlbum.members,
                                                   cover: toAlbum.cover,
                                                   dateCreated: toAlbum.dateCreated,
                                                   dateModified: Date())
                
                albumFilesProvider.add(models: newAlbumFiles, reloadData: reloadDBData)
                albumsProvider.update(models: [updatedAlbum], reloadData: reloadDBData)
                
                success?(response)
            }, failure: failure)
     
        } catch {
            failure?(WorkerError.error(error: error))
        }
        
    }
    
    func moveFilesToGallery(fromAlbum: STLibrary.Album, files: [STLibrary.AlbumFile], isMoving: Bool, reloadDBData: Bool = true, success: Success<STEmptyResponse>?, failure: Failure?) {
        
        let files = files.filter({ $0.isRemote == true })
        guard !files.isEmpty else {
            success?(STEmptyResponse())
            return
        }
        
        let crypto = STApplication.shared.crypto
        do {
            let publicKey = try crypto.readPublicKey()
            let fromAlbumData = try crypto.decryptAlbum(albumPKStr: fromAlbum.publicKey, encAlbumSKStr: fromAlbum.encPrivateKey, metadataStr: fromAlbum.metadata)
            
            var newHeaders = [String: String]()
            var galeryFiles = [STLibrary.File]()
            
            for file in files {
                let newHeader = try crypto.reencryptFileHeaders(headersStr: file.headers, publicKeyTo: publicKey, privateKeyFrom: fromAlbumData.privateKey, publicKeyFrom: fromAlbumData.publicKey)
                newHeaders[file.file] = newHeader
                let file = try STLibrary.File(file: file.file, version: file.version, headers: newHeader, dateCreated: file.dateCreated, dateModified: file.dateModified, isRemote: true)
                galeryFiles.append(file)
            }
            
            let request = STAlbumRequest.moveFile(fromSet: .album, toSet: .file, albumIdFrom: fromAlbum.albumId, albumIdTo: nil, isMoving: isMoving, headers: newHeaders, files: galeryFiles)
            
            let albumFilesProvider = STApplication.shared.dataBase.albumFilesProvider
            let galleryProvider = STApplication.shared.dataBase.galleryProvider
            
            self.request(request: request, success: { (response: STEmptyResponse) in
                if isMoving {
                    albumFilesProvider.delete(models: files, reloadData: reloadDBData)
                }
                galleryProvider.add(models: galeryFiles, reloadData: reloadDBData)
                success?(response)
            }, failure: failure)
            
        } catch {
            failure?(WorkerError.error(error: error))
        }
        
    }
    
}