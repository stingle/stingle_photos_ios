//
//  STPlayer.swift
//  Stingle
//
//  Created by Khoren Asatryan on 5/19/21.
//

import AVKit

class STPlayer {
    
    let player = AVPlayer()
    
    private(set) var file: STLibrary.File?
    
    private var assetResourceLoader: STAssetResourceLoader?
    private let dispatchQueue = DispatchQueue(label: "Player.Queue", attributes: .concurrent)
    
//    func replaceCurrentItem(with file: STLibrary.File?) {
//        self.file = file
//        let url = URL(string: "https://storage.googleapis.com/gvabox/media/samples/android.mp4")
//        let item = CachingPlayerItem(url: url!)
//        self.player.replaceCurrentItem(with: item)
//    }
    
    func replaceCurrentItem(with file: STLibrary.File?) {
        self.file = file

        guard let file = file, let fileHeader = file.decryptsHeaders.file else {
            self.player.replaceCurrentItem(with: nil)
            return
        }

//        let url = STApplication.shared.fileSystem.cacheThumbsURL?.appendingPathComponent("IMG_0055.MP4")
        let url = file.fileOreginalUrl
        
        let resourceLoader = STAssetResourceLoader(with: url!, header: fileHeader, fileExtension: nil)
        self.assetResourceLoader = resourceLoader
        let item = AVPlayerItem(asset: resourceLoader.asset, automaticallyLoadedAssetKeys: nil)
        self.player.replaceCurrentItem(with: item)
    }
    
    func play(file: STLibrary.File?) {
        self.replaceCurrentItem(with: file)
        self.play()
    }
    
    func play() {
        self.player.play()
    }
    
}
