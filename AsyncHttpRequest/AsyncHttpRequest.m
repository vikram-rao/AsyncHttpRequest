//
//  AsyncHttpRequest.m
//  AsyncHttpRequest
//
//  Created by Vikram Rao on 20/10/14.
//  Copyright (c) 2014 Vikram Rao. All rights reserved.
//

#import "AsyncHttpRequest.h"
#import <UIKit/UIKit.h>

@interface AsyncHttpRequest ()

@property (nonatomic) NSURLConnection *conn;
@property (nonatomic) NSMutableData *data;
@property (nonatomic, copy) void (^block)(id, NSData *, NSError *);
@property (nonatomic, copy) void (^statusBlock)(NSString *);

@end

@implementation AsyncHttpRequest

- (void) initializeRequest:(void (^)(id, NSData *, NSError *))block
               statusBlock:(void (^)(NSString *))statusBlock
{
    self.data = [NSMutableData data];
    self.block = block;
    self.statusBlock = statusBlock;
}

- (NSData *)getJsonEncodedParams:(NSDictionary *)params
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&error];
    if (error)
        NSLog(@"%@",error);
    return jsonData;
}

- (NSData *)getEncodedParams:(NSDictionary *)params json:(BOOL)json
{
    NSData *paramsAsData;
    if (json) {
        paramsAsData = [self getJsonEncodedParams:params];
    } else {
        NSString *paramsAsString = [self getUrlEncodedParams:params];
        paramsAsData = [paramsAsString dataUsingEncoding:NSUTF8StringEncoding];
    }
    return paramsAsData;
}

- (void)setContentType:(NSMutableURLRequest *)req json:(BOOL)json
{
    if (json) {
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
}

- (void)sendUpdateRequest:(void (^)(NSString *))statusBlock block:(void (^)(id, NSData *, NSError *))block url:(NSString *)url json:(BOOL)json params:(NSDictionary *)params method:(NSString *)method
{
    [self initializeRequest:block statusBlock:statusBlock];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSData *paramsAsData = [self getEncodedParams:params json:json];
    [self setContentType:req json:json];
    [req setHTTPMethod:method];
    [req setValue:[NSString stringWithFormat:@"%lu", (unsigned long)paramsAsData.length] forHTTPHeaderField:@"Content-length"];
    [req setHTTPBody:paramsAsData];
    
    [self connect:req];
}

- (void)sendAsyncPostRequest:(NSString *)url
                      params:(NSDictionary *)params
                        json:(BOOL)json
                       block:(void (^)(id, NSData *, NSError *))block
                 statusBlock:(void (^)(NSString *))statusBlock
{
    [self sendUpdateRequest:statusBlock block:block url:url json:json params:params method:@"POST"];
}

- (void)sendAsyncPutRequest:(NSString *)url
                     params:(NSDictionary *)params
                       json:(BOOL)json
                      block:(void (^)(id, NSData *, NSError *))block
                statusBlock:(void (^)(NSString *))statusBlock
{
    [self sendUpdateRequest:statusBlock block:block url:url json:json params:params method:@"PUT"];
}

- (void)sendStatusUpdate:(NSString *)message
{
    if (!self.statusBlock || self.statusBlock == NULL)
        return;
    self.statusBlock(message);
}

- (void) connect:(NSURLRequest *)request
{
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (!conn) {
        self.block(nil, nil, [NSError errorWithDomain:@"" code:1 userInfo:nil]);
        return;
    }
    self.conn = conn;
    [conn start];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self sendStatusUpdate:@"Connecting..."];
}

- (NSString *) getUrlEncodedParams:(NSDictionary *)params
{
    NSMutableString *paramsAsString = [NSMutableString string];
    BOOL firstParam = YES;
    for (NSString *key in params.allKeys) {
        id value = [params valueForKey:key];
        @try {
            NSData *valueAsData = [NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];
            value = [[NSString alloc] initWithData:valueAsData encoding:NSUTF8StringEncoding];
        }
        @catch (NSException *exception) {}
        if (firstParam) {
            firstParam = NO;
        } else {
            [paramsAsString appendString:@"&"];
        }
        [paramsAsString appendString:[NSString stringWithFormat:@"%@=%@",key,[self getEscapedString:value]]];
    }
    
    return paramsAsString;
}

- (NSString *) getEscapedString:(NSString *)unescapedString
{
    if (![unescapedString isKindOfClass:[NSString class]]) {
        return unescapedString;
    }
    NSString *escapedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (CFStringRef)unescapedString,
                                                                                                    NULL,
                                                                                                    (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                    kCFStringEncodingUTF8 ));
    return escapedString;
}

- (void)sendAsyncGetRequest:(NSString *)url
                     params:(NSDictionary *)params
                      block:(void (^)(id, NSData *, NSError *))block
                statusBlock:(void (^)(NSString *))statusBlock
{
    [self initializeRequest:block statusBlock:statusBlock];
    NSString *paramsAsString = [self getUrlEncodedParams:params];
    
    [self sendStatusUpdate:[NSString stringWithFormat:@"PARAMS - %@", paramsAsString]];
    url = [NSString stringWithFormat:@"%@?%@",url,paramsAsString];
    [self sendStatusUpdate:[NSString stringWithFormat:@"URL - %@", url]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self connect:req];
}

- (void)sendAsyncDeleteRequest:(NSString *)url
                        params:(NSDictionary *)params
                         block:(void (^)(id, NSData *, NSError *))block
                   statusBlock:(void (^)(NSString *))statusBlock
{
    [self initializeRequest:block statusBlock:statusBlock];
    NSString *paramsAsString = [self getUrlEncodedParams:params];
    
    [self sendStatusUpdate:[NSString stringWithFormat:@"PARAMS - %@", paramsAsString]];
    url = [NSString stringWithFormat:@"%@?%@",url,paramsAsString];
    [self sendStatusUpdate:[NSString stringWithFormat:@"URL - %@", url]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:@"DELETE"];
    [self connect:req];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    self.block(nil, nil, error);
    [self sendStatusUpdate:error.description];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (self.block) {
        NSError *error;
        id data = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&error];
        self.block(data, self.data, error);
    } else {
        [self sendStatusUpdate:@"Finished downloading data"];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    NSInteger code = [httpResponse statusCode];
    if (code != 200) {
        self.block(nil, nil, [[NSError alloc] initWithDomain:@"HTTPError" code:code userInfo:@{}]);
        [self cancel];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.data appendData:data];
    [self sendStatusUpdate:[NSString stringWithFormat:@"Got %lu bytes", (unsigned long)self.data.length]];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    [self sendStatusUpdate:@"Got auth challenge"];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        [self sendStatusUpdate:@"Ignoring SSL"];
        SecTrustRef trust = challenge.protectionSpace.serverTrust;
        NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
        [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
        return;
    }
    [self sendStatusUpdate:@"Cancelling SSL"];
    [[challenge sender] cancelAuthenticationChallenge:challenge];
}

- (void)cancel
{
    self.block = nil;
    self.data = nil;
    [self.conn cancel];
    self.conn = nil;
}

- (void)dealloc
{
    [self cancel];
}

@end
