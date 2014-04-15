#import "foundation_request.h"

#include <memory>
#include <string>
#include <functional>
#include <llmr/platform/platform.hpp>
#include <uv.h>


uv_once_t request_initialize = UV_ONCE_INIT;
dispatch_queue_t queue = nullptr;
NSURLSession *session = nullptr;


void request_initialize_cb() {
    queue = dispatch_queue_create("Parsing", DISPATCH_QUEUE_CONCURRENT);

    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForResource = 6;
    sessionConfig.HTTPMaximumConnectionsPerHost = 8;
    sessionConfig.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;

    session = [NSURLSession sessionWithConfiguration:sessionConfig];
}

namespace llmr {

class platform::Request {
public:
    Request(NSURLSessionDataTask *task, const std::string &original_url)
        : task(task), original_url(original_url) {}
    NSURLSessionDataTask *task;
    std::string original_url;
};

std::shared_ptr<platform::Request>
platform::request_http(const std::string &url, std::function<void(Response *)> background_function,
                       std::function<void()> foreground_callback) {

    uv_once(&request_initialize, request_initialize_cb);

    __block std::shared_ptr<Request> req;
    NSURLSessionDataTask *task = [session
                                  dataTaskWithURL:[NSURL URLWithString:@(url.c_str())]
                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Make sure we clear the shared_ptr to resolve the circular reference. We're referencing
        // this shared_ptr by value so that the object stays around until this completion handler is
        // invoked.
        req.reset();

        if ([error code] == NSURLErrorCancelled) {
            // We intentionally cancelled this request. Do nothing.
            [[NSNotificationCenter defaultCenter] postNotificationName:MBXUpdateActivityNotification object:nil];
            return;
        }

        dispatch_async(queue, ^(){
            Response res;

            if (!error && [response isKindOfClass:[NSHTTPURLResponse class]]) {
                res.code = [(NSHTTPURLResponse *)response statusCode];
                res.body = {(const char *)[data bytes], [data length]};
            } else {
                res.code = -1;
                res.error_message = [[error localizedDescription] UTF8String];
            }

            background_function(&res);

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                foreground_callback();

                [[NSNotificationCenter defaultCenter] postNotificationName:MBXUpdateActivityNotification object:nil];
            });
        });
    }];

    req = std::make_shared<Request>(task, url);
    [task resume];
    [[NSNotificationCenter defaultCenter] postNotificationName:MBXUpdateActivityNotification object:nil];
    return req;
}

void platform::cancel_request_http(const std::shared_ptr<Request> &req) {
    if (req) {
        [req->task cancel];
    }
}

}