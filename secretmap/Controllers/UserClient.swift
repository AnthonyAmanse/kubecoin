//
//  UserClient.swift
//  kubecoin
//
//  Created by Joe Anthony Peter Amanse on 9/3/18.
//  Copyright © 2018 Anton McConville. All rights reserved.
//

import Foundation
import UIKit

class UserClient {
    
    var event: String
    
    init(event: String) {
        self.event = event
    }
    
    // MARK: - Get User details from blockchain
    
    func getUserFromBlockchain() {
        
    }
    
    // MARK: - Get Contracts of User From blockchain network
    
    func getContractsFromBlockchain() {
        
    }
    
    // MARK: - Register User to blockchain and Save to MongoDB
    
    // onCompletion returns - userId, name, avatar
    func registerUser(_ onCompletion: @escaping (String, String, String) -> Void) {
        guard let url = URL(string: BlockchainGlobals.URL + "api/execute") else { return }
        let parameters: [String:Any]
        let request = NSMutableURLRequest(url: url)
        
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        parameters = ["type":"enroll", "queue":"user_queue-" + self.event, "params":[]]
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: [])
        
        let enrollUser = session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            if let data = data {
                do {
                    // Convert the data to JSON
                    let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    
                    if let json = jsonSerialized, let status = json["status"], let resultId = json["resultId"] {
                        NSLog(status as! String)
                        NSLog(resultId as! String) // Use this one to get blockchain payload - should contain userId
                        
                        // Start pinging backend with resultId
                        self.requestResults(resultId: resultId as! String, attemptNumber: 0, onCompletion)
                    }
                }  catch let error as NSError {
                    print(error.localizedDescription)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        enrollUser.resume()
    }
    
    private func requestResults(resultId: String, attemptNumber: Int, _ onCompletion: @escaping (String, String, String) -> Void) {
        if attemptNumber < 60 {
            guard let url = URL(string: BlockchainGlobals.URL + "api/results/" + resultId) else { return }
            
            let session = URLSession.shared
            let enrollUser = session.dataTask(with: url) { (data, response, error) in
                if let data = data {
                    do {
                        // data is
                        // {"status":"done","result":"{\"message\":\"success\",\"result\":{\"user\":\"ffc22a44-a34a-453b-997a-117f00ec651e\",\"txId\":\"67a76bf0063ed13a41448d9428f21ee3cf345e4ed90ba2edf0e2ddea569c3a16\"}}"}
                        
                        // Convert the data to JSON
                        let backendResult = try JSONDecoder().decode(BackendResult.self, from: data)
                        // if the status from queue is done
                        if backendResult.status == "done" {
                            
                            let resultOfEnroll = try JSONDecoder().decode(ResultOfEnroll.self, from: backendResult.result!.data(using: .utf8)!)
                            print(resultOfEnroll.result!.user)
                            self.sendToMongo(userId: resultOfEnroll.result!.user, onCompletion)
                        }
                        else {
                            let when = DispatchTime.now() + 1.5 // 1.5 seconds from now
                            DispatchQueue.main.asyncAfter(deadline: when) {
                                self.requestResults(resultId: resultId, attemptNumber: attemptNumber+1, onCompletion)
                            }
                        }
                        
                    }  catch let error as NSError {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
            enrollUser.resume()
        }
        else {
            NSLog("Attempted 60 times to enroll... No results")
        }
    }
    
    func sendToMongo(userId: String, _ onCompletion: @escaping (String, String, String) -> Void) {
        guard let url = URL(string: BlockchainGlobals.URL + "registerees/" + self.event + "/add") else { return }
        let parameters: [String:Any]
        let request = NSMutableURLRequest(url: url)
        
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        parameters = ["registereeId": userId, "steps":0, "calories":0, "device":"ios"]
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: [])
        
        let saveAsRegisteree = session.dataTask(with: request as URLRequest) { (data, response, error) in
            if let data = data {
                do {
                    // Convert the data to JSON
                    let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    
                    if let json = jsonSerialized, let name = json["name"], let png = json["png"] {
                        onCompletion(userId, name as! String, png as! String)
                    }
                }  catch let error as NSError {
                    print(error.localizedDescription)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
            
        }
        saveAsRegisteree.resume()
    }
}
