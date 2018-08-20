//
//  Oplytic.swift
//  Oplytic
//
//  Copyright © 2017 Oplytic. All rights reserved.
////
import UIKit
import AdSupport

let MAXRECORDCOUNT = 1000
let DEVICETOKEN_KEY = "dt"
let APPID_KEY = "aid"
let CLIENTEVENTTOKEN_KEY = "cet"
let CLICKTOKEN_KEY = "ct"
let EVENTID_KEY = "eid"
let EVENTACTION_KEY = "ea"
let EVENTOBJECT_KEY = "eo"
let STR1_KEY = "s1"
let STR2_KEY = "s2"
let STR3_KEY = "s3"
let NUM1_KEY = "n1"
let NUM2_KEY = "n2"
let TIMESTAMP_KEY = "ts"
let INSTALL_ACTION_KEY = "Install"
let ATTRIBUTE_ACTION_KEY = "Attribute"
let PURCHASE_ACTION_KEY = "Purchase"
let OPLYTIC_UNIVERSAL_LINK_NOTIFICATION = "oplunivlink"

public protocol OplyticAttributionHandler {
    func onAttribution(data: [String: String])
}

public class Oplytic
{
    private static var _appLink : String = ""
    private static var _appId : String = ""
    private static var _deviceToken : String = ""
    private static var _clickToken : String = ""
    private static var _cache : OPLDBCache? = nil
    public static var OplyticAttributionHandler: OplyticAttributionHandler?

    public static func start()
    {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                setup()
        }
    }

    private static func setup()
    {
        if(_cache == nil){
            _appLink = ".oplct.com"
            if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
                // use swift dictionary as normal
                if let oplyticAppName = dict["oplyticappname"] {
                    _appLink = (oplyticAppName as! String) + _appLink
                }
            }

            _appId = Bundle.main.bundleIdentifier!
            _deviceToken = getDeviceToken()
            let clickToken = getClickToken()
            if(clickToken == nil){
                _clickToken = ""
            }
            else{
                _clickToken = clickToken!
            }

            _cache = OPLDBCache.sharedInstance

            subscribeToBackgroundEvents()

            let clickUrl = getInstallClickUrl()
            if(clickUrl != nil){
                tryAttribute(clickUrl:clickUrl!)
            }
            if(_cache!.NewlyInstalled) {
                addInstallEvent();
            }
        }
    }

    private static func reset(){

        UserDefaults.standard.set(nil, forKey: DEVICETOKEN_KEY)
        UserDefaults.standard.set(nil, forKey: CLICKTOKEN_KEY)
    }

    private static func subscribeToBackgroundEvents() {
        NotificationCenter.default.addObserver(Oplytic.self,
                                               selector: #selector(Oplytic.onEnterBackground),
                                               name: NSNotification.Name.UIApplicationDidEnterBackground,
                                               object: nil)

        NotificationCenter.default.addObserver(Oplytic.self,
                                               selector: #selector(Oplytic.onEnterForeground),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
    }

    @objc static func onEnterBackground(notification : NSNotification) {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                _cache?.sendEvents()
        }
    }

    @objc static func onEnterForeground(notification : NSNotification) {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                _cache?.sendEvents()
        }
    }

    private static func getDeviceToken() -> String {
        var token : String? = UserDefaults.standard.object(forKey: DEVICETOKEN_KEY) as? String
        if (token == nil)
        {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled
            {
                token = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            }
        }
        if (token == nil)
        {
            token = UUID().uuidString
        }
        UserDefaults.standard.set(token, forKey: DEVICETOKEN_KEY)
        return token!
    }

    private static func getClickToken() -> String? {
        return (UserDefaults.standard.object(forKey: CLICKTOKEN_KEY) as? String)
    }

    private static func setClickToken(clickToken : String) {
        UserDefaults.standard.set(clickToken, forKey: CLICKTOKEN_KEY)
    }

    public static func handleUniversalLink(userActivity : NSUserActivity) {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                setup()
                processUniversalLink(userActivity: userActivity)
        }
    }

    private static func processUniversalLink(userActivity: NSUserActivity) {
        if (userActivity.activityType == NSUserActivityTypeBrowsingWeb)
        {
            let webPageURL = userActivity.webpageURL
            if(webPageURL != nil) {
                let clickUrl = "\(webPageURL!)"
                if (clickUrl.contains("/" + _appLink)){
                    tryAttribute(clickUrl:clickUrl)
                }
            }
        }
    }

    public static func addPurchaseEvent(item : String,
                                        itemId: String,
                                        quantity: Double,
                                        price: Double,
                                        currency_unit : String) {
        addEvent(eventAction: PURCHASE_ACTION_KEY,
                 eventObject: item,
                 eventId: itemId,
                 str1: currency_unit,
                 str2: nil,
                 str3: nil,
                 num1: quantity,
                 num2: price)
    }


    private static func addInstallEvent() {
        var adidString : String? = nil
        if ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        {
            adidString = "ADID"
        }
        addEvent(eventAction: INSTALL_ACTION_KEY,
                 eventObject: adidString,
                 eventId: nil,
                 str1: nil,
                 str2: nil,
                 str3: nil,
                 num1: nil,
                 num2: nil)
    }

    private static func getInstallClickUrl() -> String? {
        guard let text = UIPasteboard.general.string else { return nil }
        guard let data = Data(base64Encoded: text) else { return nil }
        guard let clickUrl = String(data: data, encoding: .utf8) else { return nil}
        if (clickUrl.contains("/" + _appLink)){
            UIPasteboard.general.strings = []
            return clickUrl
        }
        return nil
    }

    private static func tryAttribute(clickUrl:String){
        var pushClickUrl = false
        var clickToken = extractClickToken(clickUrl: clickUrl)
        if(clickToken == nil){
            clickToken = UUID().uuidString
            pushClickUrl = true
        }
        if(clickToken == _clickToken) { return; } //no dupe
        _clickToken = clickToken!
        setClickToken(clickToken: _clickToken)
        addAttributeEvent(clickToken: clickToken!, clickUrl: clickUrl, pushClickUrl: pushClickUrl)
    }

    private static func extractClickToken(clickUrl:String)->String?{
        if (clickUrl.contains("/" + _appLink)) {
            var clickToken: String? = nil
            if clickUrl.count > 40 {
                let s1 = clickUrl.index(clickUrl.endIndex, offsetBy: -40)
                let e1 = clickUrl.index(clickUrl.endIndex, offsetBy: -37)
                let s2 = clickUrl.index(clickUrl.endIndex, offsetBy: -36)
                let e2 = clickUrl.index(clickUrl.endIndex, offsetBy: -1)
                let ct = clickUrl[s1...e1]
                if(ct == "&ct=" || ct == "?ct="){
                    clickToken = String(clickUrl[s2...e2])
                    return clickToken
                }
            }
        }
        return nil
    }

    private static func addAttributeEvent(clickToken: String, clickUrl : String, pushClickUrl: Bool)
    {
        var eventObject:String? = nil
        if(pushClickUrl){
            eventObject = clickUrl
        }

        addEvent(eventAction: ATTRIBUTE_ACTION_KEY,
                 eventObject: eventObject,
                 eventId: nil,
                 str1: nil,
                 str2: nil,
                 str3: nil,
                 num1: nil,
                 num2: nil)

        if(OplyticAttributionHandler != nil){
            var data = [String: String]()
            let queryItems = URLComponents(string: clickUrl)?.queryItems
            if(queryItems != nil){
                for qi in queryItems! {
                    let paramName = qi.name.lowercased()
                    let paramValue = qi.value
                    data[paramName] = paramValue
                }
            }
            OplyticAttributionHandler?.onAttribution(data: data)
        }
    }

    public static func addEvent(eventAction: String? = nil,
                                eventObject: String? = nil,
                                eventId : String? = nil,
                                str1: String? = nil, str2: String? = nil, str3: String? = nil,
                                num1 : Double? = nil, num2: Double? = nil)
    {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                setup()

                var data : [String : String] = [:]

                let clientEventId = UUID().uuidString

                data[CLIENTEVENTTOKEN_KEY] = clientEventId
                data[DEVICETOKEN_KEY] = _deviceToken
                data[CLICKTOKEN_KEY] = _clickToken
                data[APPID_KEY] = _appId

                if eventAction != nil {
                    data[EVENTACTION_KEY] = eventAction!
                }
                if eventObject != nil {
                    data[EVENTOBJECT_KEY] = eventObject!
                }
                if eventId != nil {
                    data[EVENTID_KEY] = eventId!
                }
                if str1 != nil {
                    data[STR1_KEY] = str1!
                }
                if str2 != nil {
                    data[STR2_KEY] = str2!
                }
                if str3 != nil {
                    data[STR3_KEY] = str3!
                }
                if num1 != nil {
                    data[NUM1_KEY] = "\(num1!)"
                }
                if num2 != nil {
                    data[NUM2_KEY] = "\(num2!)"
                }
                _cache?.addEvent(data: data)
        }
    }
}

