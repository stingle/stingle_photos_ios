//
//  STFileViewerVC.swift
//  Stingle
//
//  Created by Khoren Asatryan on 5/19/21.
//

import UIKit

protocol IFileViewer: UIViewController {
    
    static func create(file: STLibrary.File, fileIndex: Int) -> IFileViewer
    var file: STLibrary.File { get }
    var fileIndex: Int { get }
    var fileViewerDelegate: IFileViewerDelegate? { get set }
    
    func fileViewer(didChangeViewerStyle fileViewer: STFileViewerVC, isFullScreen: Bool)
    func fileViewer(pauseContent fileViewer: STFileViewerVC)
    
}

protocol IFileViewerDelegate: AnyObject {
    var isFullScreenMode: Bool { get }
    func photoViewer(startFullScreen viewer: STPhotoViewerVC)
}

class STFileViewerVC: UIViewController {
    
    private var viewModel: IFileViewerVM!
    private var currentIndex: Int?
    private var pageViewController: UIPageViewController!
    private var viewControllers = STObserverEvents<IFileViewer>()
    private var viewerStyle: ViewerStyle = .white
    private weak var titleView: STFileViewerNavigationTitleView?
        
    lazy private var accessoryView: STAlbumFilesTabBarAccessoryView = {
        let resilt = STAlbumFilesTabBarAccessoryView.loadNib()
        return resilt
    }()
    
    private lazy var pickerHelper: STImagePickerHelper = {
        return STImagePickerHelper(controller: self)
    }()
    
    private var currentFile: STLibrary.File? {
        guard let currentIndex = self.currentIndex, let file = self.viewModel.object(at: currentIndex) else {
            return nil
        }
        return file
    }
    
    private var currentFileViewer: IFileViewer? {
        guard let currentIndex = self.currentIndex, let vc = self.viewControllers.objects.first(where: { $0.fileIndex == currentIndex }) else {
            return nil
        }
        return vc
    }
        
    override var prefersStatusBarHidden: Bool {
        return self.viewerStyle == .balck ? true : false
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.viewerStyle = .balck
        self.changeViewerStyle()
        self.setupTavigationTitle()
        self.viewModel.delegate = self
        self.setupPageViewController()
        self.setupTapGesture()
        self.accessoryView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.tabBarController?.tabBar as? STTabBar)?.accessoryView = self.accessoryView
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.viewerStyle == .balck {
            self.changeViewerStyle()
        }
        (self.tabBarController?.tabBar as? STTabBar)?.accessoryView = nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "pageViewController" {
            self.pageViewController = segue.destination as? UIPageViewController
            self.pageViewController.delegate = self
            self.pageViewController.dataSource = self
            
            for v in pageViewController.view.subviews {
                if let scrollView = v as? UIScrollView {
                    scrollView.delegate = self
                    break
                }
            }
        }
    }
    
    //MARK: - User action
    
    @objc private func didSelectBackground(tap: UIGestureRecognizer) {
        UIView.animate(withDuration: 0.1) {
            self.changeViewerStyle()
        }
    }
    
    //MARK: - Private methods
    
    private func setupTavigationTitle() {
        let titleView = STFileViewerNavigationTitleView()
        self.titleView = titleView
        self.navigationItem.titleView = titleView
    }
    
    private func setupPageViewController() {
        guard let viewController = self.viewController(for: self.currentIndex) else {
            return
        }
        self.pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
        self.didChangeFileViewer()
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didSelectBackground(tap:)))
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)
    }
    
    private func viewController(for index: Int?) -> IFileViewer? {
        guard let index = index, let file = self.viewModel.object(at: index), let fileType = file.decryptsHeaders.file?.fileOreginalType  else {
            return nil
        }
        switch fileType {
        case .video:
            let vc = STVideoViewerVC.create(file: file, fileIndex: index)
            vc.fileViewerDelegate = self
            self.viewControllers.addObject(vc)
            return vc
        case .image:
            let vc = STPhotoViewerVC.create(file: file, fileIndex: index)
            vc.fileViewerDelegate = self
            self.viewControllers.addObject(vc)
            return vc
        }
    }
    
    private func changeViewerStyle() {
        switch self.viewerStyle {
        case .white:
            self.view.backgroundColor = .black
            self.navigationController?.navigationBar.isHidden = true
            self.tabBarController?.tabBar.isHidden = true
            self.viewerStyle = .balck
        case .balck:
            self.view.backgroundColor = .appBackground
            self.navigationController?.navigationBar.isHidden = false
            self.tabBarController?.tabBar.isHidden = false
            self.viewerStyle = .white
        }
        
        self.splitMenuViewController?.setNeedsStatusBarAppearanceUpdate()
        self.viewControllers.forEach({ $0.fileViewer(didChangeViewerStyle: self, isFullScreen: self.viewerStyle == .balck)})
    }
    
    private func didChangeFileViewer() {
        guard let currentIndex = self.currentIndex, let file = self.viewModel.object(at: currentIndex) else {
            self.titleView?.title = nil
            self.titleView?.subTitle = nil
            return
        }
        let dateManager = STDateManager.shared
        self.titleView?.title = dateManager.dateToString(date: file.dateModified, withFormate: .mmm_dd_yyyy)
        self.titleView?.subTitle = dateManager.dateToString(date: file.dateModified, withFormate: .HH_mm)
    }
    
    private func deleteCurrentFile() {
        guard let file = self.currentFile else {
            return
        }
        STLoadingView.show(in: self.view)
        self.viewModel.deleteFile(file: file) { [weak self] error in
            guard let weakSelf = self else{
                return
            }
            STLoadingView.hide(in: weakSelf.view)
            if let error = error {
                weakSelf.showError(error: error)
            }
        }
    }
    
    private func openDownloadController(action: FilesDownloadDecryptAction) {
        guard let file = self.currentFile else {
            return
        }
        let shearing = STFilesDownloaderActivityVC.DownloadFiles.files(files: [file])
        
        STFilesDownloaderActivityVC.showActivity(downloadingFiles: shearing, controller: self.tabBarController ?? self, delegate: self, userInfo: action)
    }
    
    private func openActivityViewController(downloadedUrls: [URL], folderUrl: URL?) {
        let vc = UIActivityViewController(activityItems: downloadedUrls, applicationActivities: [])
        vc.popoverPresentationController?.sourceView = self.accessoryView.sharButton
        vc.completionWithItemsHandler = { [weak self] (type,completed,items,error) in
            if let folderUrl = folderUrl {
                self?.viewModel.removeFileSystemFolder(url: folderUrl)
            }
        }
        self.present(vc, animated: true)
    }
    
    private func saveItemsToDevice(downloadeds: [STFilesDownloaderActivityVM.DecryptDownloadFile], folderUrl: URL?) {
        var filesSave = [(url: URL, itemType: STImagePickerHelper.ItemType)]()
        downloadeds.forEach { file in
            let type: STImagePickerHelper.ItemType = file.header.fileOreginalType == .image ? .photo : .video
            let url = file.url
            filesSave.append((url, type))
        }
        self.pickerHelper.save(items: filesSave) { [weak self] in
            if let folderUrl = folderUrl {
                self?.viewModel.removeFileSystemFolder(url: folderUrl)
            }
        }
    }
    
    private func didSelectShareViaStinglePhotos() {
        guard let file = self.currentFile else {
            return
        }
        let storyboard = UIStoryboard(name: "Shear", bundle: .main)
        let vc = (storyboard.instantiateViewController(identifier: "STSharedMembersNavVCID") as! UINavigationController)
        (vc.viewControllers.first as? STSharedMembersVC)?.shearedType = .files(files: [file])
        self.showDetailViewController(vc, sender: nil)
    }
    
    private func showShareFileActionSheet(sender: UIView) {
        let alert = UIAlertController(title: "share".localized, message: nil, preferredStyle: .actionSheet)
        let stinglePhotos = UIAlertAction(title: "share_via_stingle_photos".localized, style: .default) { [weak self] _ in
            self?.didSelectShareViaStinglePhotos()
        }
        alert.addAction(stinglePhotos)
        
        let shareOtherApps = UIAlertAction(title: "share_to_other_apps".localized, style: .default) { [weak self] _ in
            self?.openDownloadController(action: .share)
        }
        alert.addAction(shareOtherApps)
        let cancelAction = UIAlertAction(title: "cancel".localized, style: .cancel)
        alert.addAction(cancelAction)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
        }
        self.showDetailViewController(alert, sender: nil)
    }
    
}


extension STFileViewerVC {
    
    static func create(galery sortDescriptorsKeys: [String], predicate: NSPredicate?, file: STLibrary.File) -> STFileViewerVC {
        let storyboard = UIStoryboard(name: "Gallery", bundle: .main)
        let vc: Self = storyboard.instantiateViewController(identifier: "STFileViewerVCID")
        let viewModel = STGaleryFileViewerVM(sortDescriptorsKeys: sortDescriptorsKeys, predicate: predicate)
        vc.viewModel = viewModel
        vc.currentIndex = viewModel.index(at: file)
        return vc
    }
    
    static func create(album: STLibrary.Album, file: STLibrary.File, sortDescriptorsKeys: [String]) -> STFileViewerVC {
        let storyboard = UIStoryboard(name: "Gallery", bundle: .main)
        let vc: Self = storyboard.instantiateViewController(identifier: "STFileViewerVCID")
        let viewModel = STAlbumFileViewerVM(album: album, sortDescriptorsKeys: sortDescriptorsKeys)
        vc.viewModel = viewModel
        vc.currentIndex = viewModel.index(at: file)
        return vc
    }
    
}

extension STFileViewerVC: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}

extension STFileViewerVC: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        guard let currentIndex = self.currentIndex, let vc = self.viewControllers.objects.first(where: { $0.fileIndex == currentIndex }) else {
            return
        }
        let org = self.view.convert(vc.view.frame.origin, from: vc.view.superview)
        let pageWidth = scrollView.frame.size.width
        let fractionalPage = (-org.x + CGFloat(currentIndex) * pageWidth) / pageWidth
        let page = lround(Double(fractionalPage))
                
        if self.currentIndex != page {
            self.currentIndex = page
            self.didChangeFileViewer()
        }
         
    }
    
}

extension STFileViewerVC: STAlbumFilesTabBarAccessoryViewDelegate {
    
    func albumFilesTabBarAccessory(view: STAlbumFilesTabBarAccessoryView, didSelectShareButton sendner: UIButton) {
        self.showShareFileActionSheet(sender: sendner)
    }
    
    func albumFilesTabBarAccessory(view: STAlbumFilesTabBarAccessoryView, didSelectMoveButton sendner: UIButton) {
        guard let file = self.currentFile else {
            return
        }
        let navVC = self.storyboard?.instantiateViewController(identifier: "goToMoveAlbumFiles") as! UINavigationController
        (navVC.viewControllers.first as? STMoveAlbumFilesVC)?.moveInfo = .files(files: [file])
        self.showDetailViewController(navVC, sender: nil)
    }
    
    func albumFilesTabBarAccessory(view: STAlbumFilesTabBarAccessoryView, didSelectDownloadButton sendner: UIButton) {
        let title = "alert_save_to_device_library_title".localized
        let message = "alert_save_file_to_device_library_message".localized
        self.showInfoAlert(title: title, message: message, cancel: true) { [weak self] in
            self?.openDownloadController(action: .saveDevicePhotos)
        }
    }
    
    func albumFilesTabBarAccessory(view: STAlbumFilesTabBarAccessoryView, didSelectTrashButton sendner: UIButton) {
        guard let file = self.currentFile else {
            return
        }
        self.currentFileViewer?.fileViewer(pauseContent: self)
        let title = self.viewModel.getDeleteFileMessage(file: file)
        self.showOkCancelAlert(title: title, message: nil) { [weak self] _ in
            self?.deleteCurrentFile()
        }
    }
    
}

extension STFileViewerVC: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let fileViewer = viewController as? IFileViewer else {
            return nil
        }
        let beforeIndex = fileViewer.fileIndex - 1
        return self.viewController(for: beforeIndex)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let fileViewer = viewController as? IFileViewer else {
            return nil
        }
        let afterIndex = fileViewer.fileIndex + 1
        return self.viewController(for: afterIndex)
    }
        
}

extension STFileViewerVC: STFileViewerVMDelegate {
    
    func fileViewerVM(didUpdateedData fileViewerVM: IFileViewerVM) {
        guard let currentIndex = self.currentIndex else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        if currentIndex < self.viewModel.countOfItems, let vc = self.viewController(for: currentIndex)  {
            self.pageViewController.setViewControllers([vc], direction: .forward, animated: true, completion: nil)
        } else if currentIndex - 1 < self.viewModel.countOfItems, let vc = self.viewController(for: currentIndex - 1) {
            self.currentIndex = currentIndex - 1
            self.pageViewController.setViewControllers([vc], direction: .reverse, animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
}

extension STFileViewerVC: STFilesDownloaderActivityVCDelegate {
    
    func filesDownloaderActivity(didEndDownload activity: STFilesDownloaderActivityVC, decryptDownloadFiles: [STFilesDownloaderActivityVM.DecryptDownloadFile], folderUrl: URL?) {
        guard let decryptAction = activity.userInfo as? FilesDownloadDecryptAction else {
            if let folderUrl = folderUrl {
                self.viewModel.removeFileSystemFolder(url: folderUrl)
            }
            return
        }
        switch decryptAction {
        case .share:
            let urls = decryptDownloadFiles.compactMap({return $0.url})
            self.openActivityViewController(downloadedUrls: urls, folderUrl: folderUrl)
        case .saveDevicePhotos:
            self.saveItemsToDevice(downloadeds: decryptDownloadFiles, folderUrl: folderUrl)
        }
    }
    
}

extension STFileViewerVC: STImagePickerHelperDelegate {}

extension STFileViewerVC: IFileViewerDelegate {
   
    func photoViewer(startFullScreen viewer: STPhotoViewerVC) {
        guard self.viewerStyle == .white else {
            return
        }
        self.changeViewerStyle()
    }
    
    var isFullScreenMode: Bool {
        return self.viewerStyle == .balck
    }
    
}

extension STFileViewerVC {
    
    enum ViewerStyle {
        case white
        case balck
    }
    
    enum FilesDownloadDecryptAction {
        case share
        case saveDevicePhotos
    }
    
}


