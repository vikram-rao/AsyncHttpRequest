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

- (void)sendAsyncPostRequest:(NSString *)url
                      params:(NSDictionary *)params
                       block:(void (^)(id, NSData *, NSError *))block
                 statusBlock:(void (^)(NSString *))statusBlock
{
    [self initializeRequest:block statusBlock:statusBlock];
    NSString *paramsAsString = [self getParamsString:params];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:@"POST"];
    
    NSData *paramsAsData = [paramsAsString dataUsingEncoding:NSUTF8StringEncoding];
    [req setValue:[NSString stringWithFormat:@"%lu", (unsigned long)paramsAsData.length] forHTTPHeaderField:@"Content-length"];
    [req setHTTPBody:paramsAsData];
    
    [self connect:req];
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
    self.statusBlock(@"Connecting...");
}

- (NSString *) getParamsString:(NSDictionary *)params
{
    //    NSLog(@"Sending - %@", params);
    NSMutableString *paramsAsString = [NSMutableString string];
    BOOL firstParam = YES;
    for (NSString *key in params.allKeys) {
        NSString *value = [params valueForKey:key];
        if (firstParam) {
            firstParam = NO;
        } else {
            [paramsAsString appendString:@"&"];
        }
        [paramsAsString appendString:[NSString stringWithFormat:@"%@=%@",key,[self getEscapedString:value]]];
    }
    paramsAsString = [[paramsAsString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    
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
    NSString *paramsAsString = [self getParamsString:params];
    
    self.statusBlock([NSString stringWithFormat:@"PARAMS - %@", paramsAsString]);
    url = [NSString stringWithFormat:@"%@?%@",url,paramsAsString];
    //    NSLog(@"URL = %@", url);
    self.statusBlock([NSString stringWithFormat:@"URL - %@", url]);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    [self connect:req];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    self.block(nil, nil, error);
    self.statusBlock(error.description);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (self.block) {
        NSError *error;
        id data = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&error];
        self.block(data, self.data, error);
    } else {
        self.statusBlock(@"Finished downloading data");
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
    self.statusBlock([NSString stringWithFormat:@"Got %lu bytes", (unsigned long)self.data.length]);
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    self.statusBlock(@"Got auth challenge");
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    //    NSLog(@"Got challenge - %@", challenge.protectionSpace.authenticationMethod);
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        self.statusBlock(@"Ignoring SSL");
        SecTrustRef trust = challenge.protectionSpace.serverTrust;
        NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
        [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
        return;
    }
    self.statusBlock(@"Cancelling SSL");
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
