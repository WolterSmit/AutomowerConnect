//
//  File.swift
//  
//
//  Created by WolterS on 17/06/2023.
//

import Foundation

struct SystemDTO: Decodable {
    var name: String
    var model: String
    var serialNumber: Int
}

struct BatteryDTO: Decodable {
    var batteryPercent: Int
}

enum ModeDTO: String, Decodable {
    case MAIN_AREA
    case SECONDARY_AREA
    case HOME
    case DEMO
    case UNKNOWN
}

enum ActivityDTO: String, Decodable {
    case UNKNOWN
    case NOT_APPLICABLE
    case MOWING
    case GOING_HOME
    case CHARGING
    case LEAVING
    case PARKED_IN_CS
    case STOPPED_IN_GARDEN
}

enum StateDTO: String, Decodable {
    case UNKNOWN
    case NOT_APPLICABLE
    case PAUSED
    case IN_OPERATION
    case WAIT_UPDATING
    case WAIT_POWER_UP
    case RESTRICTED
    case OFF
    case STOPPED
    case ERROR
    case FATAL_ERROR
    case ERROR_AT_POWER_UP
}

struct MowerDTO: Decodable {
    var mode: ModeDTO
    var activity: ActivityDTO
    var state: StateDTO
    var errorCode: Int
    var errorCodeTimestamp: Double
}

struct PositionDTO: Decodable {
    var latitude: Double
    var longitude: Double
}

struct AttributesDTO: Decodable {
    var system: SystemDTO
    var battery: BatteryDTO
    var mower: MowerDTO
    var positions: [PositionDTO]
}

struct MowerDataDTO: Decodable {
    var type: String
    var id: String
    var attributes: AttributesDTO
}

struct MowersDTO: Decodable {
    var data: [MowerDataDTO]
}
