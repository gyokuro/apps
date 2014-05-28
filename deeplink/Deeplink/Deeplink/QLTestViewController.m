//
//  QLTestViewController.m
//  Deeplink
//
//  Created by DAVID on 5/21/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLTestViewController.h"
#import "TSTapstream.h"
@interface QLTestViewController ()
@property (weak, nonatomic) IBOutlet UITextView *info;
@property (weak, nonatomic) IBOutlet UIButton *getTapstreamConversionButton;

@end

@implementation QLTestViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)onGetTapstreamConversion:(id)sender {
    
    TSTapstream *tracker = [TSTapstream instance];
    [tracker getConversionData:^(NSData *jsonInfo) {
        if(jsonInfo == nil)
        {
            _info.text = @"No info available.";
        }
        else
        {
            NSError *error;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:jsonInfo options:kNilOptions error:&error];
            if(json && !error)
            {
                // Read some data from this json object, and modify your application's behaviour accordingly
                // ...
                NSString *jsonString = [[NSString alloc] initWithData:jsonInfo encoding:NSUTF8StringEncoding];
                NSLog(@"receiveData: %@",  jsonString);
                _info.text = jsonString;
            }
        }
    }];
}

@end
