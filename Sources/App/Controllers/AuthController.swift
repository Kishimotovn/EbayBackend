//
//  AuthController.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("auth")

        groupedRoutes.post("validateResetPasswordToken", use: validateResetPasswordTokenHandler)
        groupedRoutes.post("resetPassword", use: resetPasswordHandler)
        groupedRoutes.post("requestResetPassword", use: requestResetPasswordHandler)
        groupedRoutes.post("register", use: registerBuyerHandler)
        groupedRoutes.post("refreshToken", use: refreshTokenHandler)
        groupedRoutes.post("logOut", use: logOutHandler)
        
        let passwordProtected = groupedRoutes.grouped(Buyer.authenticator())
        passwordProtected.post("login", use: loginBuyerHandler)

        let protected = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        protected.get("me", use: getMeHandler)
    }

    private func validateResetPasswordTokenHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let input = try request.content.decode(ValidateResetPasswordTokenInput.self)

        return request
            .buyerResetPasswordTokens
            .find(value: input.token)
            .unwrap(or: Abort(.badRequest, reason: "Mã đặt lại mật khẩu không hợp lệ"))
            .transform(to: .ok)
    }

    private func resetPasswordHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let input = try request.content.decode(ResetPasswordInput.self)

        return request.buyerResetPasswordTokens
            .find(value: input.resetPasswordToken)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .tryFlatMap { token -> EventLoopFuture<Void> in
                guard input.password == input.confirmPassword else {
                    throw Abort(.badRequest, reason: "Mật khẩu xác nhận không khớp")
                }

                let newPassword = try Bcrypt.hash(input.password)
                token.buyer.passwordHash = newPassword

                return request
                    .buyers
                    .save(buyer: token.buyer)
                    .flatMap {
                        return request.buyerResetPasswordTokens.deleteAll(buyerID: token.buyer.id!)
                }
            }.transform(to: .ok)
    }

    private func requestResetPasswordHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let input = try request.content.decode(RequestResetPasswordInput.self)

        return request
            .buyers
            .find(email: input.email)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .tryFlatMap { buyer -> EventLoopFuture<Void> in
                let newResetPasswordToken = try buyer.generateResetPasswordToken()
                return request
                    .buyerResetPasswordTokens
                    .save(buyerResetPasswordToken: newResetPasswordToken)
                    .tryFlatMap {
                        return try request.emails.sendResetPasswordEmail(for: buyer, resetPasswordToken: newResetPasswordToken)
                }
            }.transform(to: .ok)
    }

    private func logOutHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let input = try request.content.decode(RefreshTokenInput.self)

        return request
            .buyerTokens
            .find(value: input.refreshToken)
            .optionalFlatMapThrowing { token in
                return try request.buyerTokens.delete(id: token.requireID())
        }.transform(to: .ok)
    }

    private func refreshTokenHandler(request: Request) throws -> EventLoopFuture<BuyerTokensOutput> {
        let input = try request.content.decode(RefreshTokenInput.self)

        return request
            .buyerTokens
            .find(value: input.refreshToken)
            .unwrap(or: Abort(.badRequest))
            .flatMapThrowing { token -> EventLoopFuture<BuyerTokensOutput> in
                if token.expiredAt > Date() {
                    let payload = Buyer.AccessTokenPayload(buyerID: token.$buyer.id)
                    let accessToken = try request.jwt.sign(payload)
                    
                    let newTokens = BuyerTokensOutput(
                        refreshToken: token.value,
                        accessToken: accessToken,
                        expiredAt: payload.exp.value)

                    return request.eventLoop.makeSucceededFuture(newTokens)
                } else {
                    return try request
                        .buyerTokens
                        .delete(id: token.requireID())
                        .flatMapThrowing { _ throws -> BuyerTokensOutput in
                            throw Abort(.unauthorized, reason: "RTE")
                        }
                }
            }.flatMap { $0 }
    }

    private func getMeHandler(request: Request) throws -> Buyer {
        return request.auth.get(Buyer.self)!
    }

    private func loginBuyerHandler(request: Request) throws -> EventLoopFuture<BuyerTokensOutput> {
        let buyer = try request.auth.require(Buyer.self)
        let payload = try buyer.accessTokenPayload()
        let accessToken = try request.jwt.sign(payload)
        let refreshToken = try buyer.generateToken()

        return request
            .buyerTokens
            .save(token: refreshToken)
            .map {
                let tokens = BuyerTokensOutput(
                    refreshToken: refreshToken.value,
                    accessToken: accessToken,
                    expiredAt: payload.exp.value)

                return tokens
        }
    }

    private func registerBuyerHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        try CreateBuyerInput.validate(request)

        let input = try request.content.decode(CreateBuyerInput.self)
        guard input.password == input.confirmPassword else {
            throw Abort(.badRequest, reason: "Mật khẩu xác nhận không khớp")
        }

        let buyer = try input.buyer()

        return request
            .buyers
            .save(buyer: buyer)
            .transform(to: .ok)
    }
}
