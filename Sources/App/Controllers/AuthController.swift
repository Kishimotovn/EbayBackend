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

        groupedRoutes.post("sellerRefreshToken", use: sellerRefreshTokenHandler)
        groupedRoutes.post("sellerLogOut", use: sellerLogOutHandler)
        
        let passwordProtected = groupedRoutes.grouped(BuyerBasicAuthenticator())
        passwordProtected.post("login", use: loginBuyerHandler)

        let sellerPasswordProtected = groupedRoutes.grouped(SellerBasicAuthenticator())
        sellerPasswordProtected.post("sellerLogin", use: loginSellerHandler)

        let protected = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        protected.get("me", use: getMeHandler)

        let sellerProtected = groupedRoutes
            .grouped(SellerJWTAuthenticator())
            .grouped(Seller.guardMiddleware())
        
        sellerProtected.get("seller", use: getSellerHandler)
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

    private func sellerLogOutHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let input = try request.content.decode(RefreshTokenInput.self)

        return request
            .sellerTokens
            .find(value: input.refreshToken)
            .optionalFlatMapThrowing { token in
                return try request.sellerTokens.delete(id: token.requireID())
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

    private func sellerRefreshTokenHandler(request: Request) async throws -> SellerLoginOutput {
        let input = try request.content.decode(RefreshTokenInput.self)
        
        let token = try await request
            .sellerTokens
            .find(value: input.refreshToken)
            .unwrap(or: Abort(.badRequest))
            .get()
        
        guard token.expiredAt >= Date() else {
            try await request
                .sellerTokens
                .delete(id: token.requireID())
                .get()
            throw AppError.refreshTokenExpired
        }

        let payload = Seller.AccessTokenPayload(sellerID: token.$seller.id)
        let accessToken = try request.jwt.sign(payload)
        
        let seller = try await token.$seller.get(on: request.db)
        
        return SellerLoginOutput(
            refreshToken: token.value,
            accessToken: accessToken,
            expiredAt: payload.exp.value,
            seller: seller.output()
        )
    }

    private func refreshTokenHandler(request: Request) async throws -> BuyerLoginOutput {
        let input = try request.content.decode(RefreshTokenInput.self)
        
        let token = try await request
            .buyerTokens
            .find(value: input.refreshToken)
            .unwrap(or: Abort(.badRequest))
            .get()
        
        guard token.expiredAt >= Date() else {
            try await request
                .buyerTokens
                .delete(id: token.requireID())
                .get()
            throw AppError.refreshTokenExpired
        }

        let payload = Buyer.AccessTokenPayload(buyerID: token.$buyer.id)
        let accessToken = try request.jwt.sign(payload)
        
        let buyer = try await token.$buyer.get(on: request.db)
        
        return BuyerLoginOutput(
            refreshToken: token.value,
            accessToken: accessToken,
            expiredAt: payload.exp.value,
            buyer: buyer.output()
        )
    }

    private func getSellerHandler(request: Request) throws -> Seller {
        return request.auth.get(Seller.self)!
    }

    private func getMeHandler(request: Request) throws -> Buyer {
        return request.auth.get(Buyer.self)!
    }

    private func loginSellerHandler(request: Request) async throws -> SellerLoginOutput {
        let seller = try request.auth.require(Seller.self)
        let payload = try seller.accessTokenPayload()
        let accessToken = try request.jwt.sign(payload)
        let refreshToken = try seller.generateToken()

        try await request
            .sellerTokens
            .save(token: refreshToken)
            .get()

        return SellerLoginOutput(
            refreshToken: refreshToken.value,
            accessToken: accessToken,
            expiredAt: payload.exp.value,
            seller: seller.output()
        )
   }

    private func loginBuyerHandler(request: Request) async throws -> BuyerLoginOutput {
        let buyer = try request.auth.require(Buyer.self)

        guard buyer.verifiedAt != nil else {
            throw AppError.buyerNotVerified
        }

        let payload = try buyer.accessTokenPayload()
        let accessToken = try request.jwt.sign(payload)
        let refreshToken = try buyer.generateToken()
        
        try await request.buyerTokens.save(token: refreshToken).get()

        return BuyerLoginOutput.init(
            refreshToken: refreshToken.value,
            accessToken: accessToken,
            expiredAt: refreshToken.expiredAt,
            buyer: buyer.output()
        )
    }

    private func registerBuyerHandler(request: Request) async throws -> HTTPResponseStatus {
        try CreateBuyerInput.validate(content: request)

        let input = try request.content.decode(CreateBuyerInput.self)
        guard input.password == input.confirmPassword else {
            throw AppError.confirmPasswordDoesntMatch
        }

        let buyer = try input.buyer()

        try await request
            .buyers
            .save(buyer: buyer)
            .get()
        
        return .ok
    }
}
