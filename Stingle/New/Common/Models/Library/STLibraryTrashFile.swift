//
//  STLibraryTrashFile.swift
//  Stingle
//
//  Created by Khoren Asatryan on 3/11/21.
//

import Foundation

extension STLibrary {
    
    class TrashFile: File {
        
        typealias ManagedModel = STCDTrashFile
        
        required init(model: STCDTrashFile) throws {
            try super.init(file: model.file,
                           version: model.version,
                           headers: model.headers,
                           dateCreated: model.dateCreated,
                           dateModified: model.dateModified)
        }
        
        required init(model: STCDFile) throws {
            fatalError("init(model:) has not been implemented")
        }
        
        required init(from decoder: Decoder) throws {
            try super.init(from: decoder)
        }
        
    }
    
}
