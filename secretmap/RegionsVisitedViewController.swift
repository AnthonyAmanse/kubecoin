//
//  RegionsVisitedViewController.swift
//  kubecoin
//
//  Created by Joe Anthony Peter Amanse on 5/7/18.
//  Copyright © 2018 Anton McConville. All rights reserved.
//

import UIKit

class RegionsVisitedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var regionsTable: UITableView!
    
    var regionsVisited: [String]?

    @IBAction func backButton(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        regionsTable.backgroundColor = UIColor.clear
        regionsTable.tableFooterView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getRegionsVisited()
    }
    
    func getRegionsVisited() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        var currentPerson:Person
        
        var people: [Person] = []
        
        do {
            people = try context.fetch(Person.fetchRequest())
            
            if( people.count > 0 ){
                currentPerson = people[0]
                
                regionsVisited = currentPerson.regions
                regionsTable.dataSource = self
                regionsTable.reloadData()
            }
        }catch{
            print("problem getting regions visited")
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (regionsVisited?.count)!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = regionsTable.dequeueReusableCell(withIdentifier: "regionCell")
        cell?.textLabel?.text = regionsVisited?[indexPath.row]
        cell?.backgroundColor = UIColor.clear
        return cell!
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
