//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Fluent

struct CreateDefaultOrderOptions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let expressOption = OrderOption(name: "EXP", rate: 20500)
        let semiExpressOption = OrderOption(name: "S-EXP", rate: 19500)
        let standardOption = OrderOption(name: "STD", rate: 19000)

        let allOptions = [expressOption, semiExpressOption, standardOption]
        let allOptionsFuture = allOptions.map {
            $0.save(on: database)
        }

        return EventLoopFuture.andAllSucceed(allOptionsFuture, on: database.eventLoop)
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        let defaultOptionNames = [
            "EXP",
            "S-EXP",
            "STD"
        ]
        return OrderOption
            .query(on: database)
            .filter(\.$name ~~ defaultOptionNames)
            .delete()
    }
}
