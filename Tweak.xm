#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

static NSString * const DCKeyAuthAPI = @"https://keyauth.win/api/1.2/";
static NSString * const DCKeyAuthName = @"Nson48679's Application";
static NSString * const DCKeyAuthOwnerID = @"3OffCALgVd";
static NSString * const DCKeyAuthVersion = @"1.1";
static NSString * const DCSavedLicenseKey = @"darkcheatvn.saved.license";
static NSString * const DCHwidKey = @"darkcheatvn.keyauth.hwid";
static NSString * const DCEncKey = @"darkcheatvn.keyauth.enckey";

typedef void (^DCJSONCompletion)(NSDictionary *json, NSError *error);

static UIWindow *DCGateWindow = nil;

static NSString *DCPersistentUUID(NSString *storageKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *value = [defaults stringForKey:storageKey];
    if (value.length == 0) {
        value = [[NSUUID UUID] UUIDString];
        [defaults setObject:value forKey:storageKey];
        [defaults synchronize];
    }
    return value;
}

static NSURL *DCKeyAuthURL(NSDictionary<NSString *, NSString *> *params) {
    NSURLComponents *components = [NSURLComponents componentsWithString:DCKeyAuthAPI];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];

    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [items addObject:[NSURLQueryItem queryItemWithName:key value:value ?: @""]];
    }];

    components.queryItems = items;
    return components.URL;
}

static void DCKeyAuthRequest(NSDictionary<NSString *, NSString *> *params, DCJSONCompletion completion) {
    NSURL *url = DCKeyAuthURL(params);
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"DarkCheatKeyGate" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid KeyAuth URL"}];
        completion(nil, error);
        return;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    config.timeoutIntervalForRequest = 20.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            [session finishTasksAndInvalidate];
            return;
        }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if ([http isKindOfClass:[NSHTTPURLResponse class]] && (http.statusCode < 200 || http.statusCode >= 300)) {
            NSString *message = [NSString stringWithFormat:@"KeyAuth HTTP %ld", (long)http.statusCode];
            NSError *httpError = [NSError errorWithDomain:@"DarkCheatKeyGate" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey: message}];
            completion(nil, httpError);
            [session finishTasksAndInvalidate];
            return;
        }

        NSDictionary *json = nil;
        if (data.length > 0) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if ([object isKindOfClass:[NSDictionary class]]) {
                json = (NSDictionary *)object;
            }
        }

        if (!json) {
            NSError *jsonError = error ?: [NSError errorWithDomain:@"DarkCheatKeyGate" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid KeyAuth response"}];
            completion(nil, jsonError);
            [session finishTasksAndInvalidate];
            return;
        }

        completion(json, nil);
        [session finishTasksAndInvalidate];
    }];

    [task resume];
}

static NSString *DCMessageFromJSON(NSDictionary *json, NSString *fallback) {
    id message = json[@"message"];
    if ([message isKindOfClass:[NSString class]] && [message length] > 0) {
        return (NSString *)message;
    }
    return fallback;
}

static void DCVerifyLicense(NSString *license, void (^completion)(BOOL ok, NSString *message)) {
    NSDictionary *initParams = @{
        @"type": @"init",
        @"ver": DCKeyAuthVersion,
        @"name": DCKeyAuthName,
        @"ownerid": DCKeyAuthOwnerID,
        @"hash": @"undefined",
        @"enckey": DCPersistentUUID(DCEncKey),
    };

    DCKeyAuthRequest(initParams, ^(NSDictionary *initJSON, NSError *initError) {
        if (initError) {
            completion(NO, initError.localizedDescription ?: @"Khong ket noi duoc KeyAuth.");
            return;
        }

        BOOL initOK = [initJSON[@"success"] boolValue];
        NSString *sessionID = [initJSON[@"sessionid"] isKindOfClass:[NSString class]] ? initJSON[@"sessionid"] : nil;
        if (!initOK || sessionID.length == 0) {
            completion(NO, DCMessageFromJSON(initJSON, @"Khoi tao KeyAuth that bai."));
            return;
        }

        NSDictionary *licenseParams = @{
            @"type": @"license",
            @"key": license ?: @"",
            @"sessionid": sessionID,
            @"name": DCKeyAuthName,
            @"ownerid": DCKeyAuthOwnerID,
            @"hwid": DCPersistentUUID(DCHwidKey),
        };

        DCKeyAuthRequest(licenseParams, ^(NSDictionary *loginJSON, NSError *loginError) {
            if (loginError) {
                completion(NO, loginError.localizedDescription ?: @"Khong ket noi duoc KeyAuth.");
                return;
            }

            BOOL loginOK = [loginJSON[@"success"] boolValue];
            completion(loginOK, DCMessageFromJSON(loginJSON, loginOK ? @"Key hop le." : @"Key khong dung hoac da het han."));
        });
    });
}

@interface DCKeyGateViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) NSLayoutConstraint *progressWidthConstraint;
@property (nonatomic, assign) BOOL attemptedAutoLogin;
@end

@implementation DCKeyGateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.03 blue:0.12 alpha:1.0];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.15 green:0.04 blue:0.28 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.04 green:0.02 blue:0.09 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0.2, 0.0);
    gradient.endPoint = CGPointMake(0.8, 1.0);
    gradient.frame = self.view.bounds;
    gradient.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    [self.view.layer addSublayer:gradient];

    [self addParticles];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithRed:0.10 green:0.05 blue:0.18 alpha:0.86];
    card.layer.cornerRadius = 14.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithRed:0.75 green:0.52 blue:0.98 alpha:0.35].CGColor;
    card.layer.shadowColor = [UIColor colorWithRed:0.65 green:0.25 blue:1.0 alpha:1.0].CGColor;
    card.layer.shadowOpacity = 0.42;
    card.layer.shadowRadius = 28.0;
    card.layer.shadowOffset = CGSizeMake(0, 16);
    [self.view addSubview:card];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"DarkCheatVn";
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:31 weight:UIFontWeightBlack];
    title.layer.shadowColor = [UIColor colorWithRed:0.75 green:0.52 blue:0.98 alpha:1.0].CGColor;
    title.layer.shadowOpacity = 0.9;
    title.layer.shadowRadius = 16.0;
    title.layer.shadowOffset = CGSizeZero;
    [card addSubview:title];

    UILabel *keyLabel = [[UILabel alloc] init];
    keyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    keyLabel.text = @"Key";
    keyLabel.textColor = [UIColor colorWithRed:0.78 green:0.70 blue:0.98 alpha:1.0];
    keyLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [card addSubview:keyLabel];

    self.keyField = [[UITextField alloc] init];
    self.keyField.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyField.placeholder = @"Nhap key";
    self.keyField.textColor = UIColor.whiteColor;
    self.keyField.secureTextEntry = YES;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.returnKeyType = UIReturnKeyDone;
    self.keyField.delegate = self;
    self.keyField.layer.cornerRadius = 10.0;
    self.keyField.layer.borderWidth = 1.0;
    self.keyField.layer.borderColor = [UIColor colorWithRed:0.75 green:0.52 blue:0.98 alpha:0.35].CGColor;
    self.keyField.backgroundColor = [UIColor colorWithRed:0.07 green:0.03 blue:0.12 alpha:0.82];
    self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.keyField.leftViewMode = UITextFieldViewModeAlways;
    NSAttributedString *placeholder = [[NSAttributedString alloc] initWithString:@"Nhap key" attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.38]}];
    self.keyField.attributedPlaceholder = placeholder;
    [card addSubview:self.keyField];

    self.confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.confirmButton setTitle:@"Xac nhan" forState:UIControlStateNormal];
    [self.confirmButton setTitleColor:[UIColor colorWithRed:0.15 green:0.02 blue:0.20 alpha:1.0] forState:UIControlStateNormal];
    self.confirmButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.confirmButton.layer.cornerRadius = 10.0;
    self.confirmButton.backgroundColor = [UIColor colorWithRed:0.82 green:0.36 blue:0.98 alpha:1.0];
    self.confirmButton.layer.shadowColor = [UIColor colorWithRed:0.75 green:0.52 blue:0.98 alpha:1.0].CGColor;
    self.confirmButton.layer.shadowOpacity = 0.45;
    self.confirmButton.layer.shadowRadius = 16.0;
    self.confirmButton.layer.shadowOffset = CGSizeZero;
    [self.confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.confirmButton];

    UIView *progressTrack = [[UIView alloc] init];
    progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
    progressTrack.layer.cornerRadius = 4.0;
    progressTrack.clipsToBounds = YES;
    progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    [card addSubview:progressTrack];

    self.progressFill = [[UIView alloc] init];
    self.progressFill.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressFill.layer.cornerRadius = 4.0;
    self.progressFill.backgroundColor = [UIColor colorWithRed:0.75 green:0.52 blue:0.98 alpha:1.0];
    [progressTrack addSubview:self.progressFill];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"";
    self.statusLabel.textColor = [UIColor colorWithRed:0.78 green:0.70 blue:0.98 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [card addSubview:self.statusLabel];

    self.progressWidthConstraint = [self.progressFill.widthAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:28],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22],

        [keyLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:26],
        [keyLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [keyLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],

        [self.keyField.topAnchor constraintEqualToAnchor:keyLabel.bottomAnchor constant:8],
        [self.keyField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.keyField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.keyField.heightAnchor constraintEqualToConstant:50],

        [self.confirmButton.topAnchor constraintEqualToAnchor:self.keyField.bottomAnchor constant:14],
        [self.confirmButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.confirmButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.confirmButton.heightAnchor constraintEqualToConstant:50],

        [progressTrack.topAnchor constraintEqualToAnchor:self.confirmButton.bottomAnchor constant:16],
        [progressTrack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [progressTrack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [progressTrack.heightAnchor constraintEqualToConstant:8],

        [self.progressFill.leadingAnchor constraintEqualToAnchor:progressTrack.leadingAnchor],
        [self.progressFill.topAnchor constraintEqualToAnchor:progressTrack.topAnchor],
        [self.progressFill.bottomAnchor constraintEqualToAnchor:progressTrack.bottomAnchor],
        self.progressWidthConstraint,

        [self.statusLabel.topAnchor constraintEqualToAnchor:progressTrack.bottomAnchor constant:14],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-24],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.attemptedAutoLogin) {
        self.attemptedAutoLogin = YES;
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:DCSavedLicenseKey];
        if (savedKey.length > 0) {
            self.keyField.text = savedKey;
            [self verifyKey:savedKey autoMode:YES];
        } else {
            [self.keyField becomeFirstResponder];
        }
    }
}

- (void)addParticles {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterPosition = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2.0, -20.0);
    emitter.emitterSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, 1.0);
    emitter.emitterShape = kCAEmitterLayerLine;

    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.birthRate = 9.0;
    cell.lifetime = 12.0;
    cell.velocity = 28.0;
    cell.velocityRange = 18.0;
    cell.yAcceleration = 18.0;
    cell.scale = 0.045;
    cell.scaleRange = 0.03;
    cell.alphaSpeed = -0.035;
    cell.emissionLongitude = (CGFloat)M_PI;
    cell.emissionRange = 0.32;
    cell.color = [UIColor colorWithRed:0.82 green:0.36 blue:0.98 alpha:0.75].CGColor;
    cell.contents = (__bridge id)[self particleImage].CGImage;
    emitter.emitterCells = @[cell];
    [self.view.layer addSublayer:emitter];
}

- (UIImage *)particleImage {
    CGSize size = CGSizeMake(10, 10);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, UIColor.whiteColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self confirmTapped];
    return YES;
}

- (void)confirmTapped {
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (key.length == 0) {
        [self setStatus:@"Vui long nhap key." error:YES];
        return;
    }

    [self verifyKey:key autoMode:NO];
}

- (void)verifyKey:(NSString *)key autoMode:(BOOL)autoMode {
    self.confirmButton.enabled = NO;
    self.confirmButton.alpha = 0.68;
    [self.keyField resignFirstResponder];
    [self setStatus:autoMode ? @"Dang xac minh key da luu..." : @"Dang kiem tra KeyAuth..." error:NO];
    [self setProgress:0.18 animated:YES];

    DCVerifyLicense(key, ^(BOOL ok, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!ok) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:DCSavedLicenseKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                self.confirmButton.enabled = YES;
                self.confirmButton.alpha = 1.0;
                [self setProgress:0.0 animated:YES];
                [self setStatus:message ?: @"Key khong dung." error:YES];
                [self.keyField becomeFirstResponder];
                return;
            }

            [[NSUserDefaults standardUserDefaults] setObject:key forKey:DCSavedLicenseKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self runUnlockSequence];
        });
    });
}

- (void)runUnlockSequence {
    NSArray<NSDictionary *> *steps = @[
        @{@"text": @"License hop le. Dang khoa phien truy cap...", @"progress": @0.32},
        @{@"text": @"Dang dong bo cau hinh thiet bi...", @"progress": @0.56},
        @{@"text": @"Anti-ban dang duoc ap dung...", @"progress": @0.82},
        @{@"text": @"Hoan tat. Dang vao DarkCheatVn...", @"progress": @1.0},
    ];

    [self runStep:0 steps:steps];
}

- (void)runStep:(NSUInteger)index steps:(NSArray<NSDictionary *> *)steps {
    if (index >= steps.count) {
        [self dismissGate];
        return;
    }

    NSDictionary *step = steps[index];
    [self setStatus:step[@"text"] error:NO];
    [self setProgress:[step[@"progress"] doubleValue] animated:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.82 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self runStep:index + 1 steps:steps];
    });
}

- (void)setStatus:(NSString *)text error:(BOOL)error {
    self.statusLabel.text = text;
    self.statusLabel.textColor = error ? [UIColor colorWithRed:1.0 green:0.44 blue:0.54 alpha:1.0] : [UIColor colorWithRed:0.78 green:0.70 blue:0.98 alpha:1.0];
}

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated {
    progress = MAX(0.0, MIN(1.0, progress));
    UIView *track = self.progressFill.superview;
    CGFloat width = track.bounds.size.width * progress;

    void (^changes)(void) = ^{
        self.progressWidthConstraint.constant = width;
        [track layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.34 animations:changes];
    } else {
        changes();
    }
}

- (void)dismissGate {
    [UIView animateWithDuration:0.28 animations:^{
        DCGateWindow.alpha = 0.0;
    } completion:^(BOOL finished) {
        DCGateWindow.hidden = YES;
        DCGateWindow.rootViewController = nil;
        DCGateWindow = nil;
    }];
}

@end

static UIWindow *DCMakeGateWindow(void) {
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *activeScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            if (scene.activationState == UISceneActivationStateForegroundActive ||
                scene.activationState == UISceneActivationStateForegroundInactive) {
                activeScene = (UIWindowScene *)scene;
                break;
            }
        }

        if (!activeScene) {
            return nil;
        }

        window = [[UIWindow alloc] initWithWindowScene:activeScene];
    } else {
        window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    window.frame = UIScreen.mainScreen.bounds;
    window.windowLevel = UIWindowLevelAlert + 1000.0;
    window.rootViewController = [DCKeyGateViewController new];
    return window;
}

static void DCShowGateIfNeeded(void) {
    if (DCGateWindow) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (DCGateWindow) {
            return;
        }

        DCGateWindow = DCMakeGateWindow();
        if (!DCGateWindow) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DCShowGateIfNeeded();
            });
            return;
        }

        DCGateWindow.hidden = NO;
        [DCGateWindow makeKeyAndVisible];
    });
}

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIApplication *app = UIApplication.sharedApplication;
            if (app.applicationState != UIApplicationStateInactive || app.delegate) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    DCShowGateIfNeeded();
                });
            }

            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    DCShowGateIfNeeded();
                });
            }];

            if (@available(iOS 13.0, *)) {
                [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                    if (!DCGateWindow) {
                        DCShowGateIfNeeded();
                    }
                }];
            }
        });
    }
}
