//
//  AppDelegate.swift
//  secretmap
//
//  Created by Anton McConville on 2017-12-14.
//  Copyright © 2017 Anton McConville. All rights reserved.
//

import UIKit
import CoreData
import HealthKit
import CoreMotion
import CoreLocation
import UserNotifications


extension Notification.Name {
    static let zoneEntered = Notification.Name(
        rawValue: "zoneEntered")
}

struct iBeacon: Codable {
    let zone: Int
    let key: String
    let value: String
    let x: Int
    let y: Int
    let width: Int
}

struct iBeacons: Codable {
    let beacons:[iBeacon]
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    public var startDate: Date = Date()
    
    var healthKitEnabled = true
    
    var numberOfSteps:Int! = nil
    var distance:Double! = nil
    var averagePace:Double! = nil
    var pace:Double! = nil
    
    var pedometer = CMPedometer()
    let locationManager = CLLocationManager()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = UIColor(red:0.96, green:0.96, blue:0.94, alpha:1.0)
        UITabBar.appearance().tintColor = UIColor(red:0.71, green:0.11, blue:0.31, alpha:1.0)
        
        UINavigationBar.appearance().barTintColor = UIColor(red:0.76, green:0.86, blue:0.83, alpha:1.0)
        UINavigationBar.appearance().tintColor = UIColor.white
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor:UIColor.black]
        
        self.initializeData()
        
        locationManager.delegate = self
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            // Enable or disable features based on authorization.
            print("geofence notification granted")
        }
        
        return true
    }
    
    func geofenceEvent(forRegion region: CLRegion!) {
        print("Geofence triggered! Region is \(region.identifier)")
        
        // either show alert or make a notification
        if (UIApplication.shared.applicationState == .active) {
            // request the bonus fitcoins and show alert dialog box
            if let existingUser = loadUser() {
                requestBonusFitcoins(existingUser.userId, regionIdentifier: region.identifier, isViewActive: true)
            }
        } else {
            // request the bonus fitcoins and show notification
            if let existingUser = loadUser() {
                requestBonusFitcoins(existingUser.userId, regionIdentifier: region.identifier, isViewActive: false)
            }
        }
        // can simplify to
        // requestBonusFitcoins(existingUser.userId, regionIdentifier: region.identifier, isViewActive: UIApplication.shared.applicationState == .active)
    }
    
    func showAlert(_ region: String, isViewActive: Bool) {
        if isViewActive {
            let alert = UIAlertController(title: "You are near \(region)", message: "You are awarded some bonus fitcoins!", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Okay", style: UIAlertActionStyle.default, handler: nil))
            window?.rootViewController?.present(alert, animated: true, completion: nil)
        } else {
            let content = UNMutableNotificationContent()
            content.title = "You were near \(region)"
            content.body = "You were awarded some bonus fitcoins"
            
            let center = UNUserNotificationCenter.current()
            
            let request = UNNotificationRequest(identifier: "RewardNotification", content: content, trigger: nil)
            center.add(request, withCompletionHandler: nil)
        }
    }
    
    func requestBonusFitcoins(_ userId: String, regionIdentifier: String, isViewActive: Bool) {
        guard let url = URL(string: BlockchainGlobals.URL + "api/execute") else { return }
        let parameters: [String:Any]
        let request = NSMutableURLRequest(url: url)
        
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let args: [String] = [userId,"15"]
        parameters = ["type":"invoke", "queue":"user_queue", "params":["userId":userId,"fcn":"awardFitcoins","args":args]]
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: [])
        
        let getBonusFitcoins = session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            if let data = data {
                do {
                    // Convert the data to JSON
                    let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    
                    if let json = jsonSerialized, let status = json["status"], let resultId = json["resultId"] {
                        NSLog(status as! String)
                        NSLog(resultId as! String) // Use this one to get blockchain payload - should contain userId
                        
                        // Start pinging backend with resultId
                        self.requestResults(resultId: resultId as! String, attemptNumber: 0, regionIdentifier: regionIdentifier, isViewActive: isViewActive)
                    }
                }  catch let error as NSError {
                    print(error.localizedDescription)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        getBonusFitcoins.resume()
    }
    
    func requestResults(resultId: String, attemptNumber: Int, regionIdentifier: String, isViewActive: Bool) {
        if attemptNumber < 60 {
            guard let url = URL(string: BlockchainGlobals.URL + "api/results/" + resultId) else { return }
            
            let session = URLSession.shared
            let resultsFromBlockchain = session.dataTask(with: url) { (data, response, error) in
                if let data = data {
                    do {
                        let backendResult = try JSONDecoder().decode(BackendResult.self, from: data)
                        
                        if backendResult.status == "done" {
                            print(backendResult.result!)
                            // {"message":"success","result":{"txId":"9a22c3920adb58a08e65529a53fe4d277e4b3be938a207631287d2c317dd6800","results":{"status":200,"message":"","payload":"{\"id\":\"67de5854-53e2-4a0d-ab99-83d05f90721d\",\"memberType\":\"user\",\"fitcoinsBalance\":15,\"totalSteps\":0,\"stepsUsedForConversion\":0,\"contractIds\":null,\"generatedFitcoins\":15}"}}}
                            
                            let jsonSerialized = try JSONSerialization.jsonObject(with: (backendResult.result?.data(using: .utf8))!, options: []) as? [String: Any]
                            
                            if let json = jsonSerialized, let message = json["message"] {
                                if (message as! String == "success") {
                                    self.updateUserRegionsVisited(regionIdentifier)
                                    self.showAlert(regionIdentifier, isViewActive: isViewActive)
                                }
                            }
                        }
                        else {
                            let when = DispatchTime.now() + 3
                            DispatchQueue.main.asyncAfter(deadline: when) {
                                self.requestResults(resultId: resultId, attemptNumber: attemptNumber+1, regionIdentifier: regionIdentifier, isViewActive: isViewActive)
                            }
                        }
                    }  catch let error as NSError {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
            resultsFromBlockchain.resume()
        }
        else {
            NSLog("Attempted 60 times to request transaction result... No results")
        }
    }
    
    func updateUserRegionsVisited(_ region: String) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        var currentPerson:Person
        
        var people: [Person] = []
        
        do {
            people = try context.fetch(Person.fetchRequest())
            
            if( people.count > 0 ){
                currentPerson = people[0]
                
                if currentPerson.regions == nil {
                    currentPerson.regions = [region]
                } else {
                    currentPerson.regions?.append(region)
                }
                
                try context.save()
            }
        }catch{
            print("problem saving regions visited")
        }
    }
    
    func userHasEntered(_ region: String) -> Bool? {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        var currentPerson:Person
        
        var people: [Person] = []
        
        do {
            people = try context.fetch(Person.fetchRequest())
            
            if( people.count > 0 ){
                currentPerson = people[0]
                return currentPerson.regions?.contains(region)
            } else {
                return nil
            }
        }catch{
            print("problem saving generated avatar")
            return nil
        }
    }
    
    func initializeData(){
        
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        var currentPerson:Person
        
        var people: [Person] = []
       
        do {
           people = try context.fetch(Person.fetchRequest())
           
            if( people.count > 0 ){
                currentPerson = people[0]
                self.startDate = currentPerson.startdate!
            }else{
                let person = Person(context: context) // Link Person & Context
                person.startdate = Date()
                self.startDate = person.startdate!
                
                do{
                    try context.save()
                }catch{
                     print("Initializing local person data")
                }
            }
            
        } catch {

        }
    }
    
    
    func getStartDate() -> Date{
        return self.startDate
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "secretmap")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // load blockchain user
    func loadUser() -> BlockchainUser?  {
        return NSKeyedUnarchiver.unarchiveObject(withFile: BlockchainUser.ArchiveURL.path) as? BlockchainUser
    }

}

extension AppDelegate: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            if userHasEntered(region.identifier) == false || userHasEntered(region.identifier) == nil {
                geofenceEvent(forRegion: region)
            }
        }
    }
}

