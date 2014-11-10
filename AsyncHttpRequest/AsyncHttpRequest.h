//
//  AsyncHttpRequest.h
//  AsyncHttpRequest
//
//  Created by Vikram Rao on 20/10/14.
//  Copyright (c) 2014 Vikram Rao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AsyncHttpRequest : NSObject

- (void)sendAsyncGetRequest:(NSString *)url
                     params:(NSDictionary *)params
                      block:(void (^)(id, NSData *, NSError *))block
                statusBlock:(void (^)(NSString *))statusBlock;

- (void)sendAsyncPostRequest:(NSString *)url
                      params:(NSDictionary *)params
                        json:(BOOL)json
                       block:(void (^)(id, NSData *, NSError *))block
                 statusBlock:(void (^)(NSString *))statusBlock;

- (void)sendAsyncPutRequest:(NSString *)url
                     params:(NSDictionary *)params
                       json:(BOOL)json
                      block:(void (^)(id, NSData *, NSError *))block
                statusBlock:(void (^)(NSString *))statusBlock;

- (void)sendAsyncDeleteRequest:(NSString *)url
                        params:(NSDictionary *)params
                         block:(void (^)(id, NSData *, NSError *))block
                   statusBlock:(void (^)(NSString *))statusBlock;

- (void)cancel;

@end
