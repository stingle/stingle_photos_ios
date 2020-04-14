
import Foundation
import UIKit

enum SourceType {
	case Gallery
	case Trash
	case Album
	case SharedAlbums
}

protocol DataSourceDelegate {
	
	func imageReady(at indexPath:IndexPath)
	func originalImageReady(at index:Int)
}

class DataSource {
	public var type:SourceType
	static let db = SyncManager.db
	private static let crypto = Crypto()
	private static let network = NetworkManager()
	
	//TODO : Replace with round buffer
	private var thumbCache:[String: UIImage]
	private var imageCache:[String: UIImage]
	
	var delegate:DataSourceDelegate?
		
	init(type:SourceType) {
		self.type = type
		thumbCache = [String: UIImage]()
		imageCache = [String: UIImage]()
	}
		
	private var files:[SPFile]?  { get {
		guard let files:[SPFile] = DataSource.db.filesSortedByDate()  else {
			return nil
		}
		return files
		}
	}
	
	private var trash:[SPTrashFile]?  { get {
		guard let files:[SPTrashFile] = DataSource.db.filesSortedByDate() else {
			return nil
		}
		return files
		}
	}
	
//	MARK: - IndexPath getters
	
	public func numberOfSections()  -> Int {
		return DataSource.db.numberOfSections(for: fileType())
	}
	
	public func numberOfRows(forSecion:Int) -> Int {
		return DataSource.db.numberOfRows(for: forSecion, with: fileType())
	}
	
	public func sectionTitle(for secion:Int) -> String? {
		return DataSource.db.sectionTitle(for: secion, with: fileType())
	}
	
	func file(for indexPath:IndexPath) -> SPFileInfo? {
		return DataSource.db.fileForIndexPath(indexPath: indexPath, with: fileType())
	}
	
	func indexPath(for file:String) -> IndexPath? {
		return DataSource.db.indexPath(for: file, with: fileType())
	}
	
	func thumb(indexPath:IndexPath) -> UIImage? {
		print(indexPath)
		guard let file:SPFileInfo = DataSource.db.fileForIndexPath(indexPath: indexPath, with: fileType()) else {
			return nil
		}
		
		if let image = thumbCache[file.name] {
			return image
		}
		guard let filePath = SPFileManager.folder(for: .StorageThumbs)?.appendingPathComponent(file.name) else {
			return nil
		}
		
		guard let input = InputStream(url: filePath) else {
			return nil
		}
		input.open()
		
		let out = OutputStream.init(toMemory: ())
		out.open()
		
		DataSource.crypto.decryptFileAsync(input: input, output: out, completion: { (ok, error) in
			let body = {() -> Void in
				guard ok == true, error == nil else {
					return
				}
				let imageData = out.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data
				DispatchQueue.main.async {
					guard let image = UIImage(data:imageData) else {
						print("Ivnalid data for image")
						return
					}
					self.thumbCache[file.name] = image
					self.delegate?.imageReady(at: indexPath)
				}
			}
			body()
		})
		return nil
	}

//	MARK: - Index getters
	func numberOfFiles () -> Int {
		return DataSource.db.filesCount(for: fileType())
	}
	
	func thumb(index:Int) -> UIImage? {
		guard let file:SPFileInfo = DataSource.db.fileForIndex(index: index, for: fileType()) else {
			return nil
		}
		guard let image = thumbCache[file.name] else {
			return nil
		}
		return image
	}
	
	func image(index:Int) -> UIImage? {
		guard let file:SPFileInfo = DataSource.db.fileForIndex(index: index, for: fileType()) else {
			return nil
		}
		if let image = imageCache[file.name] {
			return image
		}
		
		
		guard let filePath = SPFileManager.folder(for: .StorageOriginals)?.appendingPathComponent(file.name) else {
			return nil
		}
		
		guard let input = InputStream(url: filePath) else {
			return nil
		}
		input.open()
		
		let out = OutputStream.init(toMemory: ())
		out.open()
		
		DataSource.crypto.decryptFileAsync(input: input, output: out, completion: { (ok, error) in
			let body = {() -> Void in
				guard ok == true, error == nil else {
					return
				}
				let imageData = out.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data
				DispatchQueue.main.async {
					guard let image = UIImage(data:imageData) else {
						print("Ivnalid data for image")
						return
					}
					self.imageCache[file.name] = image
					self.delegate?.originalImageReady(at: index)
				}
			}
			body()
		})
		return nil
	}
	
	func index(for indexPath:IndexPath) -> Int {
		return DataSource.db.index(for: indexPath, of: fileType())
	}
	
//	MARK: - Helpers
	func fileType() -> SPFileInfo.Type {
		switch type {
		case .Gallery:
			return  SPFile.self
		case .Trash:
			return  SPTrashFile.self
		default:
			return SPFileInfo.self
		}
	}
	
}
