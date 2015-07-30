//
//  GPXMapView.swift
//  MapTest
//
//  Created by Atakishiyev Orazdurdy on 7/25/15.
//  Copyright (c) 2015 orazz. All rights reserved.
//

import UIKit
import GoogleMaps

let kGreenButtonBackgroundColor: UIColor = UIColor(red: 142.0/255.0, green: 224.0/255.0, blue: 102.0/255.0, alpha: 0.90)

class GPXMapVC: UIViewController {
    
    let kButtonSmallSize: CGFloat = 48.0
    let kButtonLargeSize: CGFloat = 96.0
    let kButtonSeparation: CGFloat = 6.0
    
    var tappedCoordinates = [Double, Double]()
    var mapView: GMSMapView!
    
    let speedLabel : UILabel
    let coordsLabel: UILabel
    let trackerButton: UIButton
    let locationManager : CLLocationManager
    
    var updatedLocation = [Double,Double]()
    
    struct Config {
        static let SERVER = "http://178.62.47.141:81/viaroute?"
    }
    
    required init(coder aDecoder: NSCoder) {
        self.speedLabel = UILabel(coder: aDecoder)
        self.coordsLabel = UILabel(coder: aDecoder)
        self.trackerButton = UIButton(coder: aDecoder)
        self.locationManager = CLLocationManager()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        tappedCoordinates.append(0,0)
        updatedLocation.append(0,0)
        
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager.distanceFilter = 2
        locationManager.startUpdatingLocation()

    
        //println(decodedCoordinates?.first?.latitude)
        
        var camera = GMSCameraPosition.cameraWithLatitude(37.9411988553019,
             longitude: 58.38401544839144, zoom: 6)
        mapView = GMSMapView.mapWithFrame(CGRectZero, camera:camera)
        
        let mapH: CGFloat = self.view.bounds.size.height - 20.0
        mapView.frame = CGRect(x: 0.0, y: 20.0, width: self.view.bounds.size.width, height: mapH)
        
        mapView.myLocationEnabled = true
        mapView.delegate = self
        
        self.view.addSubview(mapView)
        
        let yCenterForButtons: CGFloat = mapView.frame.height - kButtonLargeSize/2 - 5
        let trackerW: CGFloat = kButtonLargeSize
        let trackerH: CGFloat = kButtonLargeSize
        let trackerX: CGFloat = self.mapView.frame.width/2 - 0.0 // Center of start
        let trackerY: CGFloat = yCenterForButtons
        trackerButton.frame = CGRect(x: 0, y:0, width: trackerW, height: trackerH)
        trackerButton.center = CGPoint(x: trackerX, y: trackerY)
        trackerButton.layer.cornerRadius = trackerW/2
        trackerButton.setTitle("Start Tracking", forState: .Normal)
        trackerButton.backgroundColor = kGreenButtonBackgroundColor
        trackerButton.addTarget(self, action: "trackerButtonTapped", forControlEvents: .TouchUpInside)
        trackerButton.hidden = false
        trackerButton.titleLabel?.font = UIFont.boldSystemFontOfSize(16)
        trackerButton.titleLabel?.numberOfLines = 2
        trackerButton.titleLabel?.textAlignment = .Center
        self.mapView.addSubview(trackerButton)
        
        // CoordLabel
        coordsLabel.frame = CGRect(x: self.mapView.frame.width/2 - 150, y: 14 + 2, width: 300, height: 20)
        coordsLabel.textAlignment = .Center
        coordsLabel.font = UIFont.systemFontOfSize(14)
        coordsLabel.text = "Not getting location"
        self.navigationItem.titleView = coordsLabel
        
        //speed Label
        speedLabel.frame = CGRect(x: self.mapView.frame.width/2 - 150, y: mapView.frame.height -  trackerH - 50, width: 300, height: 20)
        speedLabel.textAlignment = .Center
        speedLabel.font = UIFont.boldSystemFontOfSize(14)
        speedLabel.text = "0.00 km/h"
        //timeLabel.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        mapView.addSubview(speedLabel)
        
        let fixedbtn = UIBarButtonItem(title: "Clear", style: .Plain, target: self, action: Selector("clear"))
        self.navigationItem.rightBarButtonItem = fixedbtn
    }
    
    func clear() {
        self.mapView.clear()
        tappedCoordinates = []
        tappedCoordinates.append(updatedLocation[0].0 as Double, updatedLocation[0].1 as Double)
    }
    
    func decodePolyline(polyline: String) -> [(Double, Double)] {

        let polylineDecode = Polyline(encodedPolyline: polyline, precision: 1e6)
        let decodedCoordinates: [CLLocationCoordinate2D] = polylineDecode.coordinates!
        var coodinates = [Double, Double]()
        
        for var i = 0; decodedCoordinates.count > i; i++ {
            // println("\(decodedCoordinates[i].latitude) - \(decodedCoordinates[i].longitude)")
            coodinates.append(decodedCoordinates[i].latitude,decodedCoordinates[i].longitude)
        }
        
        polylineDecode.coordinates
        
        return coodinates
    }
    
    func post(url : String, postCompleted : (succeeded: Bool, msg: String) -> ()) {
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        var session = NSURLSession.sharedSession()
        request.HTTPMethod = "POST"
        
        var err: NSError?
        request.HTTPBody = "".dataUsingEncoding(NSUTF8StringEncoding)//NSJSONSerialization.dataWithJSONObject(params, options: nil, error: &err)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        var task = session.dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
            //println("Response: \(response)")
            var strData = NSString(data: data, encoding: NSUTF8StringEncoding)
            var err: NSError?
            var json = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error: &err) as? NSDictionary
            
            var msg = "No message"
            
            // Did the JSONObjectWithData constructor return an error? If so, log the error to the console
            if(err != nil) {
                println(err!.localizedDescription)
                let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("Error could not parse JSON: '\(jsonStr)'")
                postCompleted(succeeded: false, msg: "Error")
            }
            else {
                // The JSONObjectWithData constructor didn't return an error. But, we should still
                // check and make sure that json has a value using optional binding.
                if let parseJSON = json {
                    // Okay, the parsedJSON is here, let's get the value for 'success' out of it
                    if let route_geometry = parseJSON["route_geometry"] as? String {
                        postCompleted(succeeded: true, msg: route_geometry)
                    }
                    if let success = parseJSON["success"] as? Bool {
                        //println("Succes: \(success)")
                        postCompleted(succeeded: success, msg: "Logged in.")
                    }
                    return
                }
                else {
                    // Woa, okay the json object was nil, something went worng. Maybe the server isn't running?
                    let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                    println("Error could not parse JSON: \(jsonStr)")
                    postCompleted(succeeded: false, msg: "Error")
                }
            }
        })
        
        task.resume()
    }
    
    func trackerButtonTapped() {
        var urlWithParams = Config.SERVER
        
        for var i=0; tappedCoordinates.count > i; i++ {
            if i == 0 {
                urlWithParams += "loc=\(tappedCoordinates[i].0),\(tappedCoordinates[i].1)"
            }else{
                urlWithParams += "&loc=\(tappedCoordinates[i].0),\(tappedCoordinates[i].1)"
            }
        }
        
        self.post(urlWithParams) { (succeeded: Bool, msg: String) -> () in
            self.mapView.clear()
            if(succeeded) {
                var coordinates = self.decodePolyline(msg)
                var path = GMSMutablePath()
                for var j = 0; coordinates.count > j; j++ {
                    path.addLatitude(coordinates[j].0, longitude: coordinates[j].1)
                }
                
                var polyline = GMSPolyline(path: path)
                polyline.strokeColor = UIColor.blueColor()
                polyline.strokeWidth = 5.0
                polyline.map = self.mapView
                
                for var z = 0; self.tappedCoordinates.count > z; z++ {
                    var marker = GMSMarker()
                    marker.position = CLLocationCoordinate2DMake(self.tappedCoordinates[z].0, self.tappedCoordinates[z].1)
                    marker.title = "\(self.tappedCoordinates[z].0), \(self.tappedCoordinates[z].1)"
                    marker.snippet = ""
                    marker.map = self.mapView

                }
            }
        }
    }
}
extension GPXMapVC: GMSMapViewDelegate {
    
    func mapView(mapView: GMSMapView!, didTapAtCoordinate coordinate: CLLocationCoordinate2D) {
        tappedCoordinates.append(coordinate.latitude, coordinate.longitude)
        println(tappedCoordinates)
    }
    
    func mapView(mapView: GMSMapView!, didLongPressAtCoordinate coordinate: CLLocationCoordinate2D) {
        for var z = 0; tappedCoordinates.count > z; z++ {
            var marker = GMSMarker()
            marker.position = CLLocationCoordinate2DMake(tappedCoordinates[z].0, tappedCoordinates[z].1)
            marker.title = "Sydney"
            marker.snippet = "Australia"
            marker.map = mapView
           self.mapView.reloadInputViews()
        }
     
    }
}

extension GPXMapVC: CLLocationManagerDelegate {
    //#pragma mark - location manager Delegate
    
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("didFailWithError\(error)");
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateToLocation newLocation: CLLocation!, fromLocation oldLocation: CLLocation!) {
        //println("didUpdateToLocation \(newLocation.coordinate.latitude),\(newLocation.coordinate.longitude), Hacc: \(newLocation.horizontalAccuracy), Vacc: \(newLocation.verticalAccuracy)")
        
        updatedLocation[0].0 = newLocation.coordinate.latitude
        updatedLocation[0].1 = newLocation.coordinate.longitude
        
        tappedCoordinates[0].0 = newLocation.coordinate.latitude
        tappedCoordinates[0].1 = newLocation.coordinate.longitude
        //Update coordsLabel
        let latFormat = String(format: "%.6f", newLocation.coordinate.latitude)
        let lonFormat = String(format: "%.6f", newLocation.coordinate.longitude)
        coordsLabel.text = "(\(latFormat),\(lonFormat))"
        
        //Update speed (provided in m/s, but displayed in km/h)
        var speedFormat: String
        if newLocation.speed < 0 {
            speedFormat = "?.??"
        } else {
            speedFormat = String(format: "%.2f", (newLocation.speed * 3.6))
        }
        speedLabel.text = "\(speedFormat) km/h"
        
//        if gpxTrackingStatus == .Tracking {
//            println("didUpdateLocation: adding point to track \(newLocation.coordinate)")
//            map.addPointToCurrentTrackSegmentAtLocation(newLocation)
//        }
        
    }
}
