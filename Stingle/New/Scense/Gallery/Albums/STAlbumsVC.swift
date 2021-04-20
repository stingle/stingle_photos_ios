//
//  STAlbumsVC.swift
//  Stingle
//
//  Created by Khoren Asatryan on 4/13/21.
//

import UIKit

class STAlbumsVC: STFilesViewController<STAlbumsDataSource.ViewModel> {
        
    private let viewModel = STAlbumsVM()
    private let segueIdentifierAlbumFiles = "AlbumFiles"
    
    @IBInspectable var isSharedAlbums: Bool = true
    
    override func configureLocalize() {
        self.navigationItem.title = "albums".localized
        self.navigationController?.tabBarItem.title = "albums".localized
    }
    
    override func createDataSource() -> STCollectionViewDataSource<STAlbumsDataSource.ViewModel> {
        let dataSource = STAlbumsDataSource(collectionView: self.collectionView, isShared: self.isSharedAlbums)
        return dataSource
    }
    
    override func refreshControlDidRefresh() {
        self.viewModel.sync()
    }
 
    override func layoutSection(sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        
        let inset: CGFloat = 4
        let lineCount = layoutEnvironment.traitCollection.isIpad() ? 3 : 2
        let item = self.dataSource.generateCollectionLayoutItem()
        let itemSizeWidth = (layoutEnvironment.container.contentSize.width - 2 * inset) / CGFloat(lineCount)
        let itemSizeHeight = itemSizeWidth
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemSizeHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: lineCount)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
        group.interItemSpacing = .fixed(inset)
                
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        section.interGroupSpacing = inset
        section.removeContentInsetsReference(safeAreaInsets: self.collectionView.window?.safeAreaInsets)
        return section
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == self.segueIdentifierAlbumFiles, let albumFilesVC = segue.destination as? STAlbumFilesVC, let album = sender as? STLibrary.Album {
            albumFilesVC.album = album
        }
    }
    
}

extension STAlbumsVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let album = self.dataSource.object(at: indexPath) else {
            return
        }
        self.performSegue(withIdentifier: self.segueIdentifierAlbumFiles, sender: album)
    }
    
}