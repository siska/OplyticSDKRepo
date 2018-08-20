# OplyticSDKRepo

Oplytic provides attribution for app-to-app and mobile-web-to-app mobile marketing. Oplytic leverages the tracking provided by Universal Links (iOS) and App Links (Android) to deliver the precise attribution and re-attribution needed for mobile marketers.

Oplytic was designed with both retailer and affiliate in mind. We know how valuable that relationship is to everyone’s overall success.

​By leveraging native campaign tracking provided by iOS and Android, Oplytic tracks installs, actions and purchases within mobile apps providing precise attribution and reattribution to affiliate partners.
​
​Oplytic integrates seamlessly between your affiliate partners, Mobile Analytics Platform, Web Analytics Platform, CRM and DMPs allowing for a full measurement picture.
​
​It is our mission to embolden marketers to pursue their enterprise mobile and web strategies by helping them analyze their marketing and communication efforts, execute powerful tactics to engage users, and optimize media in channels that map to their objectives.

[![CI Status](https://img.shields.io/travis/siska/OplyticSDKRepo.svg?style=flat)](https://travis-ci.org/siska/OplyticSDKRepo)
[![Version](https://img.shields.io/cocoapods/v/OplyticSDKRepo.svg?style=flat)](https://cocoapods.org/pods/OplyticSDKRepo)
[![License](https://img.shields.io/cocoapods/l/OplyticSDKRepo.svg?style=flat)](https://cocoapods.org/pods/OplyticSDKRepo)
[![Platform](https://img.shields.io/cocoapods/p/OplyticSDKRepo.svg?style=flat)](https://cocoapods.org/pods/OplyticSDKRepo)


## Requirements

The minimum iOS Deployment Target is 10.0.

## Installation

OplyticSDKRepo is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'OplyticSDKRepo'
```

## Set-Up with Oplytic

Register your app with the Oplytic API or customer service. Simply provide a friendly one-word app name, the Bundle ID and the Team ID.

Grab the Bundle ID and Team ID from the XCode development environment. Look for these settings in the “General” tab, “Identity” and “Signing” sections.

https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistribution Guide/ConfiguringYourApp/ConfiguringYourApp.html

### Add AppName Config Setting

Open your app’s Info.plist file, mouse-over the Information Property List and hit the + sign. In the new entry, add “oplyticappname” as the Key and your app-name as the Value.

### Enable App Links

App links enable your app to be launched directly from clicks on safari and other apps. Follow the standard Apple Universal Link scenario:

https://developer.apple.com/ios/universal-links/

In your Apple iTunes developer account, under App IDs, select your application and make sure Associated Domains are enabled.

In XCode, select the project target, then click on the “Capabilities” tab. Scroll down to the “Associated Domains” option. Click on the button to turn it On, and then click on the “+” button to add the following item:

```
applinks:yourapp.oplct.com
```

Make sure you specify the App-Name you provided to Oplytic instead of “yourapp” above.

NOTE: If you want to access the deep-link-path and URL data yourself, you can access it via the userActivity.webPageUrl attribute.

NOTE: Due to an issue with iOS browser security you cannot enter or copy/paste the above links directly into the Safari URL bar. However, you can embed the link in apps, web-pages, emails, or other forms of social media.

### Include the Oplytic Library

Follow the instructions in the above "Installation" section to add the podfile to your Xcode project.

Click on your project target and under the General tab click on the “+” button in the
Embedded Binaries section. Choose OplyticSDKRepo.framework, which will also add an entry to the LinkedFramework and Libraries section.

### Use the Oplytic Library


Be sure to include Oplytic in any files that use the library:

```
Import Oplytic
```

### 1) Start the Oplytic SDK

Initialize the Oplytic SDK in your app delegate class. When the app is launched, start the SDK. Handle app-link events.

Add the following boilerplate code to your AppDelegate class:

```
func application(_ application: UIApplication, continue userActivity: NSUserActivity,
restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
    Oplytic.handleUniversalLink(userActivity: userActivity)
    return true
}

func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
    return userActivityType == NSUserActivityTypeBrowsingWeb
}
```

### 2) Track App-Events

There are just two methods for adding events. Make these calls whenever you want to track a purchase, registration, or other important app event.

The Oplytic SDK also tracks app installs and attribution events automatically. Each time the app is reached via an app-link, the SDK will register a new “last-click” attribution and all subsequent events and purchases will be credited to that link.

AddEvent is a general-purpose method:

```
public func addEvent(eventAction: String? = nil, eventObject: String? = nil, eventId: String? = nil, str1: String? = nil, str2: String? = nil, str3: String? = nil, num1: Double? = nil, num2: Double? = nil)
```

1) eventAction: a string associated with the event action, for example, “view” or “shop.”
2) eventObject: a string associated with the target of the event action, for example “map” or
an object SKU.
3) eventId: a unique string that you can pass along to associate with the event.
4) str1, str2, str3: arbitrary strings associated with the event. You can use these to pass any
sort of associated data for that event.
5) num1, num2: arbitrary Double numeric values associated with the event. You can use these
to pass any sort of associated data for that event.

AddPurchaseEvent is used specifically to track in-app purchases:

```
public func addPurchaseEvent(item: String, itemId: String, quantity: Double, price: Double, currency_unit: String)
```

1) item: Name of item being purchased.
2) Item_id: SKU or other ID associated with the item being purchased
3) quantity: Quantity of items being purchased.
4) price: Price of item being purchased.
5) currency_unit: String value representing the currency, for example: “USD”

### 3) Handle Click Attribution Data (optional)

If your app needs to know about the attributed click, assign an OplyticAttributionHandler protocol, like the simple ViewController example does below:

```
class ViewController: UIViewController, OplyticAttributionHandler {

    override func viewDidLoad() {
        Oplytic.OplyticAttributionHandler = self
        super.viewDidLoad()
    }

    func onAttribution(data: [String:String]) {
        //handle Attributed click query params
        }
    }
```

## Author

siska, rsiska1@gmail.com

## License

OplyticSDKRepo is available under the MIT license. See the LICENSE file for more info.
