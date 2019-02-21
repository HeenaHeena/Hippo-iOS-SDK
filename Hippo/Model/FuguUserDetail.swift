//
//  FuguUserDetail.swift
//  Fugu
//
//  Created by Gagandeep Arora on 31/08/17.
//  Copyright © 2017 CL-macmini-88. All rights reserved.
//

import UIKit

typealias FuguUserDetailCallback = (_ success: Bool, _ error: Error?) -> Void

public class UserTag: NSObject {
    var tagName: String? = nil
    var teamId: Int? = nil
    var tag_id: Int? = -1
    
    public init(tagName: String? = nil, teamId: Int? = nil) {
        self.tagName = tagName
        self.teamId = teamId
    }
    
    
    init(json: [String: Any]) {
        self.tagName = json["tag_name"] as? String
        self.tag_id = json["tag_id"] as? Int ?? -1
    }
}

@available(*, deprecated, renamed: "HippoUserDetail", message: "This class will no longer be available, To Continue migrate to HippoUserDetail")
@objc public class FuguUserDetail: NSObject {
    
}


@objc public class HippoUserDetail: NSObject {
    
    // MARK: - Properties
    var fullName: String?
    var email: String?
    var phoneNumber: String?
    var userUniqueKey: String?
    var addressAttribute: HippoAttributes?
    var customAttributes: [String: Any]?
    var userTags: [UserTag] = []
    var customRequest: [String: Any] = [:]
    
    
    fileprivate(set) var fuguUserID: Int? {
        get {
            return UserDefaults.standard.value(forKey: FUGU_USER_ID) as? Int
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FUGU_USER_ID)
        }
    }
    
    fileprivate(set) var fuguEnUserID: String? {
        get {
            return UserDefaults.standard.value(forKey: Fugu_en_user_id) as? String
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Fugu_en_user_id)
        }
    }
    
    // MARK: - Intializer
    override init() {}
    
    public init(fullName: String, email: String, phoneNumber: String, userUniqueKey: String, addressAttribute: HippoAttributes? = nil, customAttributes: [String: Any]? = nil, userTags: [UserTag]? = nil) {
        super.init()
        
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.userUniqueKey = userUniqueKey
        self.addressAttribute = addressAttribute ?? HippoAttributes()
        self.customAttributes = customAttributes
        
        self.userTags = userTags ?? []
    }
    
    func getUserTagsJSON() -> [[String: Any]] {
        var object = [[String: Any]]()
        
        for each in self.userTags {
            var temp = [String: Any]()
            if each.tagName == nil && each.teamId == nil {
                continue
            }
            if let id = each.teamId, id > 0 {
                temp["reseller_team_id"] = id
            }
            if let tagName = each.tagName, !tagName.trimWhiteSpacesAndNewLine().isEmpty {
                temp["tag_name"] = tagName
            }
            if temp["tag_name"] == nil && temp["reseller_team_id"] == nil {
                continue
            }
            object.append(temp)
        }
        return object
    }
    func getUserTagNameArray() -> [String] {
        var object = [String]()
        
        for each in self.userTags {
            if each.tagName == nil {
                continue
            }
            if let tagName = each.tagName, !tagName.trimWhiteSpacesAndNewLine().isEmpty {
                object.append(tagName)
            }
        }
        return object
    }
    
    // MARK: - Helpers
    func toJson() -> [String: Any] {
        var params: [String: Any] = [
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? 0,
            "device_type" : Device_Type_iOS
        ]
        
        switch HippoConfig.shared.credentialType {
        case FuguCredentialType.reseller:
            if HippoConfig.shared.resellerToken.isEmpty == false &&
                HippoConfig.shared.referenceId > 0 {
                params["reseller_token"] = HippoConfig.shared.resellerToken
                params["reference_id"] = HippoConfig.shared.referenceId
            }
            
        case FuguCredentialType.defaultType:
            if HippoConfig.shared.appSecretKey.isEmpty == false {
                params["app_secret_key"] = HippoConfig.shared.appSecretKey
            }
        }
        
        if let applicationType = HippoConfig.shared.appType,
            applicationType.isEmpty == false {
            params["app_type"] = applicationType
        }
        
        let userName = self.fullName ?? ""
        if userName.isEmpty == false { params["full_name"] = userName }
        
        let userEmail = self.email ?? ""
        if userEmail.isEmpty == false { params["email"] = userEmail }
        
        let userPhoneNumber = self.phoneNumber ?? ""
        if userPhoneNumber.isEmpty == false { params["phone_number"] = userPhoneNumber }
        
        let userUniqueKey = self.userUniqueKey ?? ""
        if userUniqueKey.isEmpty == false {
            params["user_unique_key"] = userUniqueKey
        }
        params["grouping_tags"] = getUserTagsJSON()
        if let addressInfo = addressAttribute?.toJSON() {
            params["attributes"] = addressInfo
        }
        var attributes = customAttributes ?? [:]
        if let countryInfo = TookanHelper.countryInfo {
            attributes["country_info"] = countryInfo
        }
        if !attributes.isEmpty {
            params["custom_attributes"] = attributes
        }
        
        if HippoConfig.shared.deviceToken.isEmpty == false {
            params["device_token"] = HippoConfig.shared.deviceToken
        }
        if HippoConfig.shared.voipToken.isEmpty == false {
            params["voip_token"] = HippoConfig.shared.voipToken
        }
        
        params["device_details"] = AgentDetail.getDeviceDetails()
        
        params += customRequest
        return params
    }
    
    
    // MARK: - Type Methods
    class func getUserDetailsAndConversation(completion: FuguUserDetailCallback? = nil) {
        var endPointName = FuguEndPoints.API_PUT_USER_DETAILS.rawValue
        
        if HippoConfig.shared.credentialType == .reseller {
            endPointName = FuguEndPoints.API_Reseller_Put_User.rawValue
        }
        
        let params: [String: Any]
        do {
            params = try getParamsToGetFuguUserDetails()
        } catch {
            completion?(false, error)
            return
        }
        
        HTTPClient.makeConcurrentConnectionWith(method: .POST, para: params, extendedUrl: endPointName) { (responseObject, error, tag, statusCode) in
            
            guard let response = (responseObject as? [String: Any]), statusCode == STATUS_CODE_SUCCESS, let data = response["data"] as? [String: Any] else {
                HippoConfig.shared.log.error("PutUserError: \(error.debugDescription)", level: .error)
                completion?(false, (error ?? APIErrors.statusCodeNotFound))
                return
            }
            HippoConfig.shared.log.trace("PutUserData: \(data)", level: .response)
            
            userDetailData = data
            
            if let tags = data["grouping_tags"] as? [[String: Any]] {
                HippoConfig.shared.userDetail?.userTags.removeAll()
                for each in tags {
                    HippoConfig.shared.userDetail?.userTags.append(UserTag(json: each))
                }
            }
            
            if let appSecretKey = userDetailData["app_secret_key"] as? String {
                HippoConfig.shared.appSecretKey = appSecretKey
            }
            
            if let userId = userDetailData["user_id"] as? Int {
                HippoConfig.shared.userDetail?.fuguUserID = userId
            }
            
            if let enUserId = userDetailData["en_user_id"] as? String {
                HippoConfig.shared.userDetail?.fuguEnUserID = enUserId
            }
            if let rawEmail = userDetailData["email"] as? String {
                HippoConfig.shared.userDetail?.email = rawEmail
            }
            
            if let rawName = userDetailData["full_name"] as? String {
                let existingName = HippoConfig.shared.userDetail?.fullName ?? ""
                if existingName.trimWhiteSpacesAndNewLine().isEmpty {
                   HippoConfig.shared.userDetail?.fullName = rawName.trimWhiteSpacesAndNewLine()
                }
            }
            if let customer_initial_form_info = userDetailData["customer_initial_form_info"] as? [String: Any] {
                HippoProperty.current.forms = FormData.getFormDataList(from: customer_initial_form_info)
                HippoProperty.current.formCollectorTitle = customer_initial_form_info["page_title"] as? String ?? "SUPPORT"
            } else {
                HippoProperty.current.forms = []
            }
            
            HippoProperty.current.showMessageSourceIcon = Bool.parse(key: "show_message_source", json: userDetailData, defaultValue: false)
            
            var isFaqEnabled = false
            if let is_faq_enabled = userDetailData["is_faq_enabled"] as? Bool {
                isFaqEnabled = is_faq_enabled
            }
            HippoConfig.shared.log.trace("User Login Data\(userDetailData)", level: .response)
            
            HippoConfig.shared.isVideoCallEnabled = Bool.parse(key: "is_video_call_enabled", json: userDetailData)
            HippoConfig.shared.isAudioCallEnabled = Bool.parse(key: "is_audio_call_enabled", json: userDetailData, defaultValue: false)
            HippoConfig.shared.unsupportedMessageString = userDetailData["unsupported_message"] as? String ?? ""
            HippoConfig.shared.maxUploadLimitForBusiness = userDetailData["max_file_size"] as? UInt ?? 10
            
            if let in_app_support_panel_version = userDetailData["in_app_support_panel_version"] as? Int, in_app_support_panel_version > HippoSupportList.currentFAQVersion, isFaqEnabled {
                HippoSupportList.getListForBusiness(completion: { (success, list) in
                    if success {
                        HippoSupportList.currentFAQVersion = in_app_support_panel_version
                    }
                })
            }
            if let botChannelsArray = userDetailData["conversations"] as? [[String: Any]] {
                FuguDefaults.set(value: botChannelsArray, forKey: DefaultName.conversationData.rawValue)
            }
            resetPushCount()
            
            if let lastVisibleController = getLastVisibleController() as? ConversationsViewController, let channelId = lastVisibleController.channel?.id {
                lastVisibleController.clearUnreadCountForChannel(id: channelId)
            } else {
                pushTotalUnreadCount()
            }
            completion?(true, nil)
        }
    }
    
    private class func getParamsToGetFuguUserDetails() throws -> [String: Any] {
        guard var params = HippoConfig.shared.userDetail?.toJson() else {
            throw FuguUserIntializationError.invalidUserUniqueKey
        }
        
        switch HippoConfig.shared.credentialType {
        case FuguCredentialType.reseller:
            if params["reseller_token"] == nil {
                throw FuguUserIntializationError.invalidResellerToken
            }
            
            if params["reference_id"] == nil {
                throw FuguUserIntializationError.invalidResellerToken
            }
        default:
            if params["app_secret_key"] == nil {
                throw FuguUserIntializationError.invalidAppSecretKey
            }
        }
        params["app_version_code"] = versionCode
        params["source"] = HippoSDKSource
        
        return params
    }
    class func clearAgentData() {
        HippoConfig.shared.agentDetail = nil
        AgentConversationManager.errorMessage = nil
        AgentChannelPersistancyManager.shared.clearChannels()
        HippoChannel.hashmapTransactionIdToChannelID = [:]
        resetPushCount()
        AgentDetail.agentLoginData = nil
        UnreadCount.clearAllStoredUnreadCount()
        AgentConversationManager.searchUserUniqueKeys.removeAll()
        ConversationStore.shared.clearData()
        AgentUserChannel.shared = nil
    }
    class func clearAllData() {
        FuguDefaults.removeAllPersistingData()
        
        //Clear agent data
        clearAgentData()
        
        HippoProperty.current = HippoProperty()
        //FuguConfig.shared.deviceToken = ""
        HippoConfig.shared.appSecretKey = ""
        HippoConfig.shared.resellerToken = ""
        HippoConfig.shared.referenceId = -1
        HippoConfig.shared.appType = nil
        HippoConfig.shared.userDetail = nil
        HippoConfig.shared.muidList = []
        
        userDetailData = [String: Any]()
        FuguChannelPersistancyManager.shared.clearChannels()
        HippoChannel.hashmapTransactionIdToChannelID = [:]
        
        FuguDefaults.removeObject(forKey: DefaultKey.myChatConversations)
        FuguDefaults.removeObject(forKey: DefaultKey.allChatConversations)
        
        FuguDefaults.removeObject(forKey: DefaultName.conversationData.rawValue)
        FuguDefaults.removeAllPersistingData()
        
         CallManager.shared.hungupCall()
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: FUGU_USER_ID)
        defaults.removeObject(forKey: Fugu_en_user_id)
        defaults.synchronize()
    }
    class func logoutFromFugu(completion: ((Bool) -> Void)? = nil) {
        if HippoConfig.shared.appSecretKey.isEmpty {
            completion?(false)
            return
            
        }
        var params: [String: Any] = [
            "app_secret_key": HippoConfig.shared.appSecretKey
        ]
        
        if let savedUserId = HippoConfig.shared.userDetail?.fuguEnUserID {
            params["en_user_id"] = savedUserId
        }
        
        HTTPClient.makeConcurrentConnectionWith(method: .POST, para: params, extendedUrl: FuguEndPoints.API_CLEAR_USER_DATA_LOGOUT.rawValue) { (responseObject, error, tag, statusCode) in
            clearAllData()
            
            let tempStatusCode = statusCode ?? 0
            let success = (200 <= tempStatusCode) && (300 > tempStatusCode)
            completion?(success)
        }
    }
}