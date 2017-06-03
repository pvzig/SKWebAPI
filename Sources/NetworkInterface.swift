//
// NetworkInterface.swift
//
// Copyright © 2017 Peter Zignego. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if os(Linux)
import Dispatch
#endif
import Foundation
import SKCore

public struct NetworkInterface {
    
    private let apiUrl = "https://slack.com/api/"
    private let session = URLSession(configuration: .default)
    
    internal init() {}
    
    internal func request(_ endpoint: Endpoint, parameters: [String: Any?], successClosure: @escaping ([String: Any])->Void, errorClosure: @escaping (SlackError)->Void) {
        var components = URLComponents(string: "\(apiUrl)\(endpoint.rawValue)")
        if parameters.count > 0 {
            components?.queryItems = filterNilParameters(parameters).map { URLQueryItem(name: $0.0, value: "\($0.1)") }
        }
        guard let url = components?.url else {
            errorClosure(SlackError.clientNetworkError)
            return
        }
        let request = URLRequest(url: url)
        
        session.dataTask(with: request) {(data, response, publicError) in
            do {
                successClosure(try NetworkInterface.handleResponse(data, response: response, publicError: publicError))
            } catch let error {
                errorClosure(error as? SlackError ?? SlackError.unknownError)
            }
        }.resume()
    }
    
    //Adapted from https://gist.github.com/erica/baa8a187a5b4796dab27
    internal func synchronusRequest(_ endpoint: Endpoint, parameters: [String: Any?]) -> [String: Any]? {
        var components = URLComponents(string: "\(apiUrl)\(endpoint.rawValue)")
        if parameters.count > 0 {
            components?.queryItems = filterNilParameters(parameters).map { URLQueryItem(name: $0.0, value: "\($0.1)") }
        }
        guard let url = components?.url else {
            return nil
        }
        let request = URLRequest(url: url)
        var data: Data? = nil
        var response: URLResponse? = nil
        var error: Error? = nil
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { (reqData, reqResponse, reqError) in
            data = reqData
            response = reqResponse
            error = reqError
            if data == nil, let error = error { print(error) }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return try? NetworkInterface.handleResponse(data, response: response, publicError: error)
    }
    
    internal func customRequest(_ url: String, data: Data, success: @escaping (Bool)->Void, errorClosure: @escaping (SlackError)->Void) {
        guard let string = url.removingPercentEncoding, let url =  URL(string: string) else {
            errorClosure(SlackError.clientNetworkError)
            return
        }
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        let contentType = "application/json"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        session.dataTask(with: request) {(data, response, publicError) in
            if publicError == nil {
                success(true)
            } else {
                errorClosure(SlackError.clientNetworkError)
            }
        }.resume()
    }
    
    internal func uploadRequest(data: Data, parameters: [String: Any?], successClosure: @escaping ([String: Any])->Void, errorClosure: @escaping (SlackError)->Void) {
        var components = URLComponents(string: "\(apiUrl)\(Endpoint.filesUpload.rawValue)")
        if parameters.count > 0 {
            components?.queryItems = filterNilParameters(parameters).map { URLQueryItem(name: $0.0, value: "\($0.1)") }
        }
        guard let url = components?.url, let filename = parameters["filename"] as? String, let filetype = parameters["filetype"] as? String else {
            errorClosure(SlackError.clientNetworkError)
            return
        }
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        let boundaryConstant = randomBoundary()
        let contentType = "multipart/form-data; boundary=" + boundaryConstant
        let boundaryStart = "--\(boundaryConstant)\r\n"
        let boundaryEnd = "--\(boundaryConstant)--\r\n"
        let contentDispositionString = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
        let contentTypeString = "Content-Type: \(filetype)\r\n\r\n"
        
        guard let boundaryStartData = boundaryStart.data(using: .utf8), let dispositionData = contentDispositionString.data(using: .utf8), let contentTypeData = contentTypeString.data(using: .utf8), let boundaryEndData = boundaryEnd.data(using: .utf8) else {
            errorClosure(SlackError.clientNetworkError)
            return
        }
        
        var requestBodyData = Data()
        requestBodyData.append(contentsOf: boundaryStartData)
        requestBodyData.append(contentsOf: dispositionData)
        requestBodyData.append(contentsOf: contentTypeData)
        requestBodyData.append(contentsOf: data)
        requestBodyData.append(contentsOf: boundaryEndData)
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBodyData as Data
        
        session.dataTask(with: request) {(data, response, publicError) in
            do {
                successClosure(try NetworkInterface.handleResponse(data, response: response, publicError: publicError))
            } catch let error {
                errorClosure(error as? SlackError ?? SlackError.unknownError)
            }
        }.resume()
    }
    
    internal static func handleResponse(_ data: Data?, response: URLResponse?, publicError: Error?) throws -> [String: Any] {
        guard let data = data, let response = response as? HTTPURLResponse else {
            throw SlackError.clientNetworkError
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw SlackError.clientJSONError
            }
            
            switch response.statusCode {
            case 200:
                if (json["ok"] as! Bool == true) {
                    return json
                } else {
                    if let errorString = json["error"] as? String {
                        throw SlackError(rawValue: errorString) ?? .unknownError
                    } else {
                        throw SlackError.unknownError
                    }
                }
            case 429:
                throw SlackError.tooManyRequests
            default:
                throw SlackError.clientNetworkError
            }
        } catch let error {
            if let slackError = error as? SlackError {
                throw slackError
            } else {
                throw SlackError.unknownError
            }
        }
    }
    
    private func randomBoundary() -> String {
        #if os(Linux)
            return "slackkit.boundary.\(Int(random()))\(Int(random()))"
        #else
            return "slackkit.boundary.\(arc4random())\(arc4random())"
        #endif
    }
    
    //MARK: - Filter Nil Parameters
    private func filterNilParameters(_ parameters: [String: Any?]) -> [String: Any] {
        var finalParameters = [String: Any]()
        for (key, value) in parameters {
            if let unwrapped = value {
                finalParameters[key] = unwrapped
            }
        }
        return finalParameters
    }
}
