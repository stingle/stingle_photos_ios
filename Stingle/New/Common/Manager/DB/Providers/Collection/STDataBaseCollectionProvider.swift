//
//  STDataBaseCollectionProvider.swift
//  Stingle
//
//  Created by Khoren Asatryan on 3/14/21.
//

import CoreData
import UIKit

extension STDataBase {
    
    class DataBaseCollectionProvider<Model: ICDConvertable, ManagedModel: IManagedObject, DeleteFile: ILibraryDeleteFile>: DataBaseProvider<Model> {
        
        let dataSources = STObserverEvents<STDataBase.DataSource<ManagedModel>>()
                
        override init(container: STDataBaseContainer) {
            super.init(container: container)
        }
        
        //MARK: - Sync insert
        
        func sync(db models: [Model]?, context: NSManagedObjectContext, lastDate: Date) throws -> Date {
            guard let models = models, !models.isEmpty else {
                return lastDate
            }
            let inserts = try self.getInsertObjects(with: models)
            guard inserts.lastDate >= lastDate, !inserts.json.isEmpty else {
                return max(lastDate, inserts.lastDate)
            }
            let insertRequest = NSBatchInsertRequest(entityName: ManagedModel.entityName, objects: inserts.json)
            let _ = try context.execute(insertRequest)
            return inserts.lastDate
        }
               
        func getInsertObjects(with files: [Model]) throws -> (json: [[String : Any]], lastDate: Date) {
            //Implement in chid classes
            throw STDataBase.DataBaseError.dateNotFound
        }
        
        //MARK: - Sync delete
        
        func deleteObjects(_ deleteFiles: [DeleteFile]?, in context: NSManagedObjectContext, lastDate: Date) throws -> Date {
            guard let deleteFiles = deleteFiles, !deleteFiles.isEmpty else {
                return lastDate
            }
            let result = try self.getDeleteObjects(deleteFiles, in: context)
            guard result.date >= lastDate, !result.models.isEmpty else {
                return max(lastDate, result.date)
            }
            
            let objectIDs = result.models.compactMap { (model) -> NSManagedObjectID? in
                return model.objectID
            }
            let deleteRequest = NSBatchDeleteRequest(objectIDs: objectIDs)
            let _ = try context.execute(deleteRequest)
            return result.date
        }
        
        func getDeleteObjects(_ deleteFiles: [DeleteFile], in context: NSManagedObjectContext) throws -> (models: [ManagedModel], date: Date) {
            throw STDataBase.DataBaseError.dateNotFound
        }
        
        func getObjects(by models: [Model], in context: NSManagedObjectContext) throws -> [ManagedModel] {
            throw STDataBase.DataBaseError.dateNotFound
        }
        
        func updateObjects(by models: [Model], managedModels: [ManagedModel], in context: NSManagedObjectContext) throws {
            throw STDataBase.DataBaseError.dateNotFound
        }
                
        func didStartSync() {
            self.dataSources.forEach { (controller) in
                controller.didStartSync()
            }
        }
        
        func finishSync() {
            self.dataSources.forEach { (controller) in
                controller.reloadData()
                controller.didEndSync()
            }
        }
        
        func reloadData() {
            self.dataSources.forEach { (controller) in
                controller.reloadData()
            }
        }
        
        //MARK: - DataSource
        
        func createDataSource(sortDescriptorsKeys: [String], sectionNameKeyPath: String?) -> DataSource<ManagedModel> {
            let dataSource = STDataBase.DataSource<ManagedModel>(sortDescriptorsKeys: sortDescriptorsKeys, viewContext: self.container.viewContext, sectionNameKeyPath: sectionNameKeyPath)
            self.dataSources.addObject(dataSource)
            return dataSource
        }
        
        func add(models: [Model], reloadData: Bool) {
            let context = self.container.newBackgroundContext()
            context.mergePolicy = NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType
            context.performAndWait {
                do {
                    if let inserts = try? self.getInsertObjects(with: models) {
                        let insertRequest = NSBatchInsertRequest(entityName: ManagedModel.entityName, objects: inserts.json)
                        insertRequest.resultType = .objectIDs
                        let _ = try context.execute(insertRequest)
                    }
                    let objects = try self.getObjects(by: models, in: context)
                    try self.updateObjects(by: models, managedModels: objects, in: context)
                    if context.hasChanges {
                        try? context.save()
                    }
                    
                } catch {
                    print(error)
                }
            }
            if reloadData {
                self.reloadData()
            }
        }
        
        func fetch(format predicateFormat: String, arguments argList: CVaListPointer) -> [Model] {
            let predicate = NSPredicate(format: predicateFormat, arguments: argList)
            let cdModels: [ManagedModel] = self.fetch(predicate: predicate)
            var results = [Model]()
            for cdModel in cdModels {
                if let model = try? cdModel.createModel() as? Model  {
                    results.append(model)
                }
            }
            return results
        }
        
        func fetch(format predicateFormat: String, _ args: CVarArg...) -> [Model] {
            let predicate = NSPredicate(format: predicateFormat, args)
            let cdModels: [ManagedModel] = self.fetch(predicate: predicate)
            var results = [Model]()
            for cdModel in cdModels {
                if let model = try? cdModel.createModel() as? Model  {
                    results.append(model)
                }
            }
            return results
        }
        
        func fetchAll() -> [Model] {
            let cdModels: [ManagedModel] = self.fetch(predicate: nil)
            var results = [Model]()
            for cdModel in cdModels {
                if let model = try? cdModel.createModel() as? Model  {
                    results.append(model)
                }
        
            }
            return results
        }
        
        func fetch(predicate: NSPredicate?) -> [ManagedModel] {
            let context = self.container.newBackgroundContext()
            context.mergePolicy = NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType
            return context.performAndWait { () -> [ManagedModel] in
                let fetchRequest = NSFetchRequest<ManagedModel>(entityName: ManagedModel.entityName)
                fetchRequest.includesSubentities = false
                fetchRequest.predicate = predicate
                let cdModels = try? context.fetch(fetchRequest)
                return cdModels ?? []
            }
        }
        
        
    }

}
