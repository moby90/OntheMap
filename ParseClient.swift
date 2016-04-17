//
//  ParseClient.swift
//  On the Map
//
//  Created by Moritz Nossek on 03.04.16.
//  Copyright © 2016 moritz nossek. All rights reserved.
//

import Foundation

class ParseClient : NSObject {
    
    
    
    var session: NSURLSession
    var completionHandler : ((success: Bool, errorString: String?) -> Void)? = nil
    var studentLocations: [StudentInformation] = []
    
    override init() {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        session = NSURLSession(configuration: config)
        super.init()
    }
    
    func dateToString(date: NSDate) -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-DD"
        return dateFormatter.stringFromDate(date)
    }
    
    //"https://api.parse.com/1/classes/StudentLocation?limit=100"
    func getParseURL(date: NSDate) -> NSURL? {
        let urlComponents = NSURLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.parse.com"
        urlComponents.path = "/1/classes/StudentLocation"
        
        let limitQuery = NSURLQueryItem(name: "limit", value: "100")
        let updatedAtQuery = NSURLQueryItem(name: "updatedAt", value: dateToString(date))
        
        urlComponents.queryItems = [limitQuery, updatedAtQuery]
        
        return urlComponents.URL
    }
    
    // MARK: - Parse API Call Functions
    
    // retrieve last 100 students and add them to the studentLocations array
    func getStudentLocationsUsingCompletionHandler(completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        let request = NSMutableURLRequest(URL: self.getParseURL(NSDate())!)
        request.addValue(Constants.parseAppId, forHTTPHeaderField: "X-Parse-Application-Id")
        request.addValue(Constants.parseApiKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        let task = session.dataTaskWithRequest(request) { data, response, error in
            
            guard error == nil else {
                print(error)
                completionHandler(success: false, errorString: "The internet connection appears to be offline")
                return
            }
            
            guard let data = data else {
                    return
            }
            
            let topLevelDict = try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            
            let studentsArray = topLevelDict["results"] as! NSArray
            
                for studentDictionary in studentsArray {
                    guard let student = self.studentLocationFromDictionary(studentDictionary as! NSDictionary) else{
                        return
                    }
                    self.studentLocations.append(student)
            }
            
            completionHandler(success: true, errorString: nil)
        }
        
        task.resume()
    }
    
    // post the logged-in user's location
    func postStudentLocation(uniqueID: String, firstName: String, lastName: String, mediaURL: String, mapString: String, locationLatitude: Double, locationLongitude: Double, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        let jsonBodyParameters: [String: AnyObject] = [
            Constants.JSONBodyKeys.UniqueKey :UdacityClient.sharedInstance().uniqueID,
            Constants.JSONBodyKeys.FirstName : UdacityClient.sharedInstance().userFirstName,
            Constants.JSONBodyKeys.LastName : UdacityClient.sharedInstance().userLastName,
            Constants.JSONBodyKeys.MediaURL : mediaURL,
            Constants.JSONBodyKeys.MapString : mapString,
            Constants.JSONBodyKeys.Latitude : locationLatitude,
            Constants.JSONBodyKeys.Longitude : locationLongitude
        ]
        
        taskForPOSTMethod(jsonBodyParameters, completionHandler: { parsedResult, error in
            
            guard let parsedData = parsedResult[Constants.JSONResponseKeys.CreatedAt] as? String else {
                completionHandler(success: false, errorString: " Could not find key : \(Constants.JSONResponseKeys.CreatedAt) in parsedResult, method : addStudentLocation/taskForPOSTMethod ")
                return
            }
            completionHandler(success: true, errorString: nil)
            
        })
    }
    
    func taskForPOSTMethod(jsonBodyParameters: [String: AnyObject], completionHandler: (result: AnyObject!, error: NSError?)->Void) -> NSURLSessionTask {
        
        /* 1. Set the parameters */
        
        /* 2. Build the URL */
        let urlString = ParseConstants.urlForPostRequest
        let url = NSURL(string: urlString)!
        
        /* 3. Configure the request */
        let request = NSMutableURLRequest(URL: url)
        
        request.HTTPMethod = "POST"
        request.addValue(Constants.parseAppId, forHTTPHeaderField: "X-Parse-Application-Id")
        request.addValue(Constants.parseApiKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(jsonBodyParameters, options: .PrettyPrinted)
        
        /* 4. Make the request */
        let task = session.dataTaskWithRequest(request) { data, response, error in
            
            /* 5/6. Parse the data and use the data (happens in the completion handler) */
            if let error = error {
                print(error.localizedDescription)
                completionHandler(result: nil, error: error)
                
            } else {
                self.parseDataWithJSONWithCompletionHandler(data, completionHandler: completionHandler)
            }
        }
        /* 7. Start the request */
        task.resume()
        return task
        
    }
    
    func parseDataWithJSONWithCompletionHandler (data: NSData!, completionHandler: (result: AnyObject!, error: NSError?)-> Void ) {
        do {
            let parsedData: AnyObject? = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            
            completionHandler(result: parsedData, error: nil)
        }
        catch let JSONError as NSError{
            completionHandler(result: nil, error: JSONError)
        }
    }
    
    // convenience method for converting JSON into a Student object
    func studentLocationFromDictionary(studentDictionary: NSDictionary) -> StudentInformation? {
        let studentFirstName = studentDictionary["firstName"] as! String
        let studentLastName = studentDictionary["lastName"] as! String
        let studentLongitude = studentDictionary["longitude"] as! Float!
        let studentLatitude = studentDictionary["latitude"] as! Float!
        let studentMediaURL = studentDictionary["mediaURL"] as! String
        let studentMapString = studentDictionary["mapString"] as! String
        let studentObjectID = studentDictionary["objectId"] as! String
        let studentUniqueKey = studentDictionary["uniqueKey"] as! String
        let initializerDictionary = ["firstName": studentFirstName, "lastName": studentLastName, "longitude": studentLongitude, "latitude": studentLatitude, "mediaURL": studentMediaURL, "mapString": studentMapString, "objectID": studentObjectID, "uniqueKey": studentUniqueKey]
        return StudentInformation(dict: initializerDictionary as! [String:AnyObject])
    }
    
    // MARK: - Shared Instance
    
    // make this class a singleton to share across classes
    class func sharedInstance() -> ParseClient {
        
        struct Singleton {
            static var sharedInstance = ParseClient()
        }
        
        return Singleton.sharedInstance
    }
}