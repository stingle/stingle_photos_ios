//
//  STWorker.swift
//  Stingle
//
//  Created by Khoren Asatryan on 2/18/21.
//  Copyright © 2021 Stingle. All rights reserved.
//

import Foundation

class STWorker {
	
	typealias Result<T> = STNetworkDispatcher.Result<T>
	typealias Success<T> = (_ result: T) -> Void
	typealias Failure = (_ error: IError) -> Void
	
	let operationManager = STOperationManager.shared
			
	//MARK: New request
	
	func request<T: IResponse>(request: IRequest, success: Success<T>? = nil, failure: Failure? = nil) {
        let operation = STNetworkOperationDecodable<T>(request: request, success: { (result) in
            success?(result)
        }) { (error) in
            failure?(error)
        }
        self.operationManager.run(operation: operation)
	}
	
	func request<T: Decodable>(request: IRequest, success: Success<T>?, failure: Failure? = nil) {
		self.request(request: request, success: { (response: STResponse<T>) in
			guard response.errors.isEmpty else {
				failure?(WorkerError.errors(errors: response.errors))
				return
			}
			guard response.status == "ok" else {
				failure?(WorkerError.status(status: response.status))
				return
			}
			guard let parts = response.parts else {
				failure?(WorkerError.emptyData)
				return
			}
			success?(parts)
		}, failure: failure)
	}
    
    func requestJSON(request: IRequest, success: Success<Any>?, failure: Failure? = nil) {
        let operation = STJSONNetworkOperation(request: request) { (json) in
            success?(json)
        } failure: { (error) in
            failure?(error)
        }
        self.operationManager.run(operation: operation)
    }
    
    func requestData(request: IRequest, success: Success<Data>?, failure: Failure? = nil) {
        let operation = STDataNetworkOperation(request: request) { (data) in
            success?(data)
        } failure: { (error) in
            failure?(error)
        }
        self.operationManager.run(operation: operation)
    }
    
}

extension STWorker {
	
	enum WorkerError: IError {
		
		case emptyData
		case error(error: Error)
		case errors(errors: [String])
		case status(status: String)
		
		var message: String {
			switch self {
			case .emptyData:
				return "empty_data".localized
			case .error(let error):
                if let error = error as? IError {
                    return error.message
                }
				return error.localizedDescription
			case .errors(let errors):
				return errors.joined(separator: "\n")
			case .status(let status):
				return status
			}
		}
	}

}
