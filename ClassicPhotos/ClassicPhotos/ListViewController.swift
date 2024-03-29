/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")!

class ListViewController: UITableViewController {
//  lazy var photos = NSDictionary(contentsOf: dataSourceURL)!
  var photos = [PhotoRecord]()
  let pendingOperations = PendingOperations()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    
    fetchPhotoDetails()
  }
  
  // MARK: - Table view data source

  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath) 
   
    if cell.accessoryView == nil {
      let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
      cell.accessoryView = indicator
    }
    
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    let photoDetails = photos[indexPath.row]
    
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    switch photoDetails.state {
    case .filtered:
      indicator.stopAnimating()
    case .failed:
      indicator.stopAnimating()
      cell.textLabel?.text = "Failed to load"
    case .new, .downloaded:
      indicator.startAnimating()
      if !tableView.isDragging && !tableView.isDecelerating {
        startOperations(for: photoDetails, at: indexPath)
      }
    }
    
    return cell
  }
  
  // MARK: - image processing

  func applySepiaFilter(_ image:UIImage) -> UIImage? {
    let inputImage = CIImage(data:UIImagePNGRepresentation(image)!)
    let context = CIContext(options:nil)
    let filter = CIFilter(name:"CISepiaTone")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter!.setValue(0.8, forKey: "inputIntensity")

    guard let outputImage = filter!.outputImage,
      let outImage = context.createCGImage(outputImage, from: outputImage.extent) else {
        return nil
    }
    return UIImage(cgImage: outImage)
  }
  
  func fetchPhotoDetails() {
    let request = URLRequest(url: dataSourceURL)
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    let task = URLSession(configuration: .default).dataTask(with: request) { data, response, error in
      let alertController = UIAlertController(title: "Ooops!",
                                              message: "There was an error fetching photo details",
                                              preferredStyle: .alert)
      
      let okAction = UIAlertAction(title: "OK", style: .default)
      alertController.addAction(okAction)
      
      if let data = data {
        do {
          let datasourceDictionary = try PropertyListSerialization.propertyList(from: data,
                                                                                options: [],
                                                                                format: nil) as! [String: String]
          
          for (name, value) in datasourceDictionary {
            let url = URL(string: value)
            if let url = url {
              let photoRecord = PhotoRecord(name: name, url: url)
              self.photos.append(photoRecord)
            }
          }
          
          DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.tableView.reloadData()
          }
        } catch {
          DispatchQueue.main.async {
            self.present(alertController, animated: true)
          }
        }
      }
      
      if error != nil {
        DispatchQueue.main.async {
          UIApplication.shared.isNetworkActivityIndicatorVisible = false
          self.present(alertController, animated: true)
        }
      }
    }
    task.resume()
  }
  
  func startOperations(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
    // download 和 filter 分开两步，在用户滑走后不进行后续的操作
    switch photoRecord.state {
    case .new:
      startDownload(for: photoRecord, at: indexPath)
    case .downloaded:
      startFiltration(for: photoRecord, at: indexPath)
    default:
      print("do nothing")
    }
  }
  
  func startDownload(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
    guard pendingOperations.downloadsInProgress[indexPath] == nil else {
      return
    }
    
    let downloader = ImageDownloader(photoRecord)
    
    downloader.completionBlock = {
      if downloader.isCancelled {
        return
      }
      
      DispatchQueue.main.async {
        self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath], with: .fade)
      }
    }
    
    pendingOperations.downloadsInProgress[indexPath] = downloader
    
    pendingOperations.downloadQueue.addOperation(downloader)
  }
  
  func startFiltration(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
    guard pendingOperations.filtrationsInProgress[indexPath] == nil else {
      return
    }
    
    let filterer = ImageFiltration(photoRecord)
    filterer.completionBlock = {
      if filterer.isCancelled {
        return
      }
      
      DispatchQueue.main.async {
        self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath], with: .fade)
      }
    }
    
    pendingOperations.filtrationsInProgress[indexPath] = filterer
    pendingOperations.filtrationQueue.addOperation(filterer)
  }
  
  func suspendAllOperations() {
    pendingOperations.downloadQueue.isSuspended = true
    pendingOperations.filtrationQueue.isSuspended = true
  }
  
  func resumeAllOperations() {
    pendingOperations.downloadQueue.isSuspended = false
    pendingOperations.filtrationQueue.isSuspended = false
  }
  
  func loadImagesForOnscreenCells() {
    guard let pathsArray = tableView.indexPathsForVisibleRows else {
      return
    }
    
    var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
    allPendingOperations.formUnion(pendingOperations.filtrationsInProgress.keys)
    
    var toBeCancelled = allPendingOperations
    let visiblePaths = Set(pathsArray)
    toBeCancelled.subtract(visiblePaths) // 所有正在进行的任务减去不可见的cell
    
    var toBeStarted = visiblePaths
    toBeStarted.subtract(allPendingOperations) // 所有可见的cell，减去已经在进行的任务
    
    for indexPath in toBeCancelled {
      if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
        pendingDownload.cancel()
      }
      pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
      if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
        pendingFiltration.cancel()
      }
      pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
    }
    
    for indexPath in toBeStarted {
      let recordToProcess = photos[indexPath.row]
      startOperations(for: recordToProcess, at: indexPath)
    }
  }
}

// MARK: - ScrollView Delegate
extension ListViewController {
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    suspendAllOperations()
  }
  
  override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      loadImagesForOnscreenCells()
      resumeAllOperations()
    }
  }
  
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    loadImagesForOnscreenCells()
    resumeAllOperations()
  }
}
