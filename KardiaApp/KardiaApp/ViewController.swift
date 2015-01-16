//
//  ViewController.swift
//  KardiaApp
//
//  Created by Charlie Depman on 12/29/14.
//  Copyright (c) 2014 Kardia. All rights reserved.
//
import UIKit

// Add new status codes here as new Python analyses are implemented
let statusCodes: [String:String] = [
    "0":"N/A", // Displayed when disconnected
    "200":"NSR",
    "404":"ARR"
]
// Prevents multiple event listeners from being registered; used later in ViewDidLoad
var firstLoad = true

var lastCode = "0"
var arrhythmiaTimes: [NSDate] = []
var bluetoothConnected = false


class ViewController: UIViewController, LineChartDelegate {
    
    // Instantiate views
    var statusView = UILabel()
    var lineChart: LineChart?
    var imgBluetoothStatus = UIImageView(image: UIImage(named:"Bluetooth-disconnected"))
    var BPMLabel = UILabel()
    var BPMView = UILabel()
    let textColor = UIColor.blueColor()
    var views: Dictionary<String, AnyObject> = [:]

    var socket: SocketIOClient!

    /**
    * Prevent autorotation
    */
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return UIInterfaceOrientation.Portrait.rawValue
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        /**********************
        *   View Rendering    *
        **********************/
        
        
        // Set Bluetooth connection status image to correct image
        if bluetoothConnected {
            self.imgBluetoothStatus.image = UIImage(named: "Bluetooth-connected")
        } else {
            self.imgBluetoothStatus.image = UIImage(named: "Bluetooth-disconnected")
        }
        
        // Set background gradient
        view.backgroundColor = UIColor.clearColor()
        var backgroundLayer = Gradient().gl
        backgroundLayer.frame = view.frame
        view.layer.insertSublayer(backgroundLayer, atIndex: 0)

        /**
        * Rendering Hexagons:
        * Hexagons are drawn as polygon layers in a CGRect UI element.
        * They are instantiated with sizes and positions relative to the size of the screen.
        */
        
        // Draw polygons
        let hexagonContainerSquareSideLength = CGRectGetWidth(view.frame) / 4
        let hexagonVerticalPosition = CGRectGetHeight(view.frame) * 19 / 24
        let connectionStatusContainer = UIView(frame: CGRect(
            x: CGRectGetWidth(view.frame) * 3 / 8,
            y: hexagonVerticalPosition,
            width: hexagonContainerSquareSideLength,
            height: hexagonContainerSquareSideLength
        ))
        let connectionStatusHexagon = drawPolygonLayer(
            x: CGRectGetWidth(connectionStatusContainer.frame) / 2,
            y: CGRectGetHeight(connectionStatusContainer.frame) / 2,
            radius: CGRectGetWidth(connectionStatusContainer.frame) / 2,
            sides: 6,
            color: UIColor.whiteColor()
        )
        connectionStatusContainer.layer.addSublayer(connectionStatusHexagon)
        
        let BPMContainer = UIView(frame: CGRect(
            x: CGRectGetWidth(view.frame) * 11 / 16,
            y: hexagonVerticalPosition,
            width: hexagonContainerSquareSideLength,
            height: hexagonContainerSquareSideLength
        ))
        let BPMHexagon = drawPolygonLayer(
            x: CGRectGetWidth(BPMContainer.frame) / 2,
            y: CGRectGetHeight(BPMContainer.frame) / 2,
            radius: CGRectGetWidth(BPMContainer.frame) / 2,
            sides: 6,
            color: UIColor.whiteColor()
        )
        BPMContainer.layer.addSublayer(BPMHexagon)
        
        let statusViewContainer = UIView(frame: CGRect(
            x: CGRectGetWidth(view.frame) * 1 / 16,
            y: hexagonVerticalPosition,
            width: hexagonContainerSquareSideLength,
            height: hexagonContainerSquareSideLength
            
        ))
        let statusViewHexagon = drawPolygonLayer(
            x: CGRectGetWidth(statusViewContainer.frame) / 2,
            y: CGRectGetHeight(statusViewContainer.frame) / 2,
            radius: CGRectGetWidth(statusViewContainer.frame) / 2,
            sides: 6,
            color: UIColor.whiteColor()
        )
        statusViewContainer.layer.addSublayer(statusViewHexagon)
        
        // Add polygons to view and give a low z-index
        view.addSubview(imgBluetoothStatus)
        view.insertSubview(connectionStatusContainer, belowSubview: imgBluetoothStatus)
        view.insertSubview(BPMContainer, belowSubview: imgBluetoothStatus)
        view.insertSubview(statusViewContainer, belowSubview: imgBluetoothStatus)

        views["connectionStatusContainer"] = connectionStatusContainer
        views["BPMContainer"] = BPMContainer
        views["statusViewContainer"] = statusViewContainer
        views["imgBluetoothStatus"] = imgBluetoothStatus

        /**
        * Render three primary views:
        * Status, connection, and BPM views are rendered and constrained to be centered in their respective hexes.
        */
        
        // Center BT connection status view in center hexagon
        imgBluetoothStatus.setTranslatesAutoresizingMaskIntoConstraints(false)
        var imgBTConstraintX = NSLayoutConstraint(
            item: imgBluetoothStatus,
            attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal,
            toItem: connectionStatusContainer,
            attribute: NSLayoutAttribute.CenterX,
            multiplier: 1,
            constant: 0
        )
        var imgBTConstraintY = NSLayoutConstraint(
            item: imgBluetoothStatus,
            attribute: NSLayoutAttribute.CenterY,
            relatedBy: NSLayoutRelation.Equal,
            toItem: connectionStatusContainer,
            attribute: NSLayoutAttribute.CenterY,
            multiplier: 1,
            constant: 0
        )
        view.addConstraints([imgBTConstraintX, imgBTConstraintY])
        
        // BPM view constraints and styling (view refers to the actual number, label is the "BPM" label
        BPMView.font = UIFont(name: "STHeitiTC-Light", size:30)
        BPMView.textColor = textColor
        BPMView.text = "- -"
        BPMView.setTranslatesAutoresizingMaskIntoConstraints(false)
        BPMView.textAlignment = NSTextAlignment.Center
        self.view.addSubview(BPMView)
        views["BPMView"] = BPMView
        var BPMViewConstraintX = NSLayoutConstraint(
            item: BPMView,
            attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal,
            toItem: BPMContainer,
            attribute: NSLayoutAttribute.CenterX,
            multiplier: 1,
            constant: 0
        )
        var BPMViewConstraintY = NSLayoutConstraint(
            item: BPMView,
            attribute: NSLayoutAttribute.CenterY,
            relatedBy: NSLayoutRelation.Equal,
            toItem: BPMContainer,
            attribute: NSLayoutAttribute.CenterY,
            multiplier: 1,
            constant: -8
        )
        view.addConstraints([BPMViewConstraintX, BPMViewConstraintY])

        BPMLabel.font = UIFont(name: "STHeitiTC-Light", size:14)
        BPMLabel.textColor = textColor
        BPMLabel.text = "BPM"
        BPMLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        BPMLabel.textAlignment = NSTextAlignment.Center
        self.view.addSubview(BPMLabel)
        views["BPMLabel"] = BPMLabel
        var BPMLabelConstraintX = NSLayoutConstraint(
            item: BPMLabel,
            attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal,
            toItem: BPMContainer,
            attribute: NSLayoutAttribute.CenterX,
            multiplier: 1,
            constant: 0
        )
        var BPMLabelConstraintY = NSLayoutConstraint(
            item: BPMLabel,
            attribute: NSLayoutAttribute.CenterY,
            relatedBy: NSLayoutRelation.Equal,
            toItem: BPMContainer,
            attribute: NSLayoutAttribute.CenterY,
            multiplier: 1,
            constant: 20
        )
        view.addConstraints([BPMLabelConstraintX, BPMLabelConstraintY])
        
        // Response code constraints and styling
        statusView.font = UIFont(name: "STHeitiTC-Light", size:26)
        statusView.textColor = textColor
        statusView.text = statusCodes[lastCode]
        statusView.setTranslatesAutoresizingMaskIntoConstraints(false)
        statusView.textAlignment = NSTextAlignment.Center
        self.view.addSubview(statusView)
        views["statusView"] = statusView
        var statusViewConstraintX = NSLayoutConstraint(
            item: statusView,
            attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal,
            toItem: statusViewContainer,
            attribute: NSLayoutAttribute.CenterX,
            multiplier: 1,
            constant: 0
        )
        var statusViewConstraintY = NSLayoutConstraint(
            item: statusView,
            attribute: NSLayoutAttribute.CenterY,
            relatedBy: NSLayoutRelation.Equal,
            toItem: statusViewContainer,
            attribute: NSLayoutAttribute.CenterY,
            multiplier: 1,
            constant: 0
        )
        view.addConstraints([statusViewConstraintX, statusViewConstraintY])
        
        
        /*****************************
        *   Sockets and Bluetooth    *
        *****************************/
        
        /**
        * Sockets
        */
        
        // Open socket connection

        socket = SocketIOClient(socketURL: "http://kardia.io")

        socket.connect()
        
        // Listen for response events from the server.
        socket.on("node.js") {data in
            // Interpret status code and display appropriate description
            if let statusCode: NSObject = data!["statusCode"]! as? NSObject {
                let code = statusCode as String
                let description = statusCodes[String(code)]!
                //Update status view on main thread to get view to update
                if lastCode != "404" && code == "404" {
                    let time = NSDate()
                    arrhythmiaTimes.append(time)
                    NSNotificationCenter.defaultCenter().postNotificationName("Abnormality", object: self, userInfo: nil)

                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.statusView.text = description
                    if code == "200" {
                        self.statusView.textColor = self.textColor
                    }
                    if code == "404" {
                        self.statusView.textColor = UIColor.redColor()
                    }
                }
                lastCode = code
            }
            
            // Display BPM
            if let BPM: NSObject = data!["heartRate"]! as? NSObject {
                let BPMnum = BPM as String
                dispatch_async(dispatch_get_main_queue()) {
                    self.BPMView.text = BPMnum
                }
            }
            
        }
        
        
        /**
        * Bluetooth event listeners
        * Listen for changes in bluetooth connection and new incoming data
        */
        

        // Listen for change in BT connection status
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("connectionChanged:"), name: BLEServiceChangedStatusNotification, object: nil)
        
        // Listen for incoming data from Bluetooth to render
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("processData:"), name: GotBLEDataNotification, object: nil)


        // Listen for incoming data (charValue) to pass to Node Server. Use the firstLoad boolean in order to avoid registering multiple event listeners.
        if (firstLoad) {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("socketCall:"), name: charValueNotification, object: nil)
                firstLoad = false
        }
    
        
        /**
        * Start the Bluetooth discovery process
        */
        btDiscoverySharedInstance
        
    }
    

    /**
    * Callback functions for Bluetooth events
    */
    
    // Callback function invoked when Bluetooth device connects or disconnects
    func connectionChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as [String: Bool]

        // Connection status changed. Reflect on interface by changing image.
        dispatch_async(dispatch_get_main_queue(), {
            if let isConnected: Bool = userInfo["isConnected"] {
                if isConnected {
                    self.imgBluetoothStatus.image = UIImage(named: "Bluetooth-connected")
                    bluetoothConnected = true
                } else {
                    self.imgBluetoothStatus.image = UIImage(named: "Bluetooth-disconnected")
                    bluetoothConnected = false
                    self.BPMView.text = "- -"
                    lastCode = "0"
                    self.statusView.text = statusCodes[lastCode]
                    self.socket.emit("/BLEDisconnect")
                }
            }
        });
    }
    
    // Callback function invoked when ViewController learns of incoming data
    func processData(notification: NSNotification) {
        // Data passed along needs to be type converted to an array of CGFloats in order to be used by lineChart

        let data = notification.userInfo!["passData"]! as [String]
        let cgFloatData = data.map {
            CGFloat(($0 as NSString).doubleValue)
        }
        
        // Draw graph with data. Dispatch_async is necessary to force execution on the main thread, which is responsible for UI (otherwise view will not update)
        dispatch_async(dispatch_get_main_queue()) {
            self.makeChart(cgFloatData)
        }
        
    }

    // Callback function for BLE incoming data that transmits to server
    func socketCall(notification: NSNotification) {
        var jsonData = notification.userInfo!["charData"]! as String
        
        socket.emit("message", args: [
            "amplitude": jsonData,
            "time": ISOStringFromDate(NSDate())
            ])
        
    }
    

    /**
    * Line Chart functionality
    */
    
    // Draw line when data is received
    func makeChart(data: [CGFloat]) {
        // if the chart is already defined, just clear it and add a line.
        if var chart: LineChart = lineChart {
            self.lineChart?.clear()
            chart.clear()
            chart.addLine(data)
        // otherwise initialize and constrain the chart and add a line.
        } else {
            // initialize with various parameters
            lineChart = LineChart()
            lineChart!.animationEnabled = false
            lineChart!.gridVisible = false
            lineChart!.dotsVisible = false
            lineChart!.axesVisible = false
            lineChart!.lineWidth = 3
            lineChart!.axisInset = -30
            lineChart!.addLine(data)
            lineChart!.delegate = self
            // set constraints
            lineChart!.setTranslatesAutoresizingMaskIntoConstraints(false)
            self.view.addSubview(lineChart!)
            views["chart"] = lineChart
            view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[chart]-|", options: nil, metrics: nil, views: views))
            var chartConstraintHeight = NSLayoutConstraint(
                item: lineChart!,
                attribute: NSLayoutAttribute.Height,
                relatedBy: NSLayoutRelation.Equal,
                toItem: view,
                attribute: NSLayoutAttribute.Height,
                multiplier: 0.4,
                constant: 0
            )
            view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-120-[chart]", options: nil, metrics: nil, views: views))
            view.addConstraints([chartConstraintHeight])
        }
    }
    
    // Linechart delegate method (unused)
    func didSelectDataPoint(x: CGFloat, yValues: Array<CGFloat>) {

    }
    
    
    // Redraw chart on device rotation - currently unused due to restriction on autorotate
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        if let chart = lineChart {
            chart.setNeedsDisplay()
        }
    }
    
    // Required for view controller protocol
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

