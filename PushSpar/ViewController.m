
//  Created by AE on 6/15/14.
//  Copyright (c) 2014 Aaron Eckhart. All rights reserved.
//

#import "ViewController.h"
#import <Parse/Parse.h>
#import "CustomTableViewCell.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, PFLogInViewControllerDelegate, PFSignUpViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *chatTextFieldOutlet;
@property (weak, nonatomic) IBOutlet UITableView *commentTableView;
@property NSString *enteredText;
@property NSArray *commentsArray;
@property NSArray *authorsArray;
@property CustomTableViewCell *customCell;

@property NSString *usernamePlaceHolder;


//future
//@property UIPushBehavior *pushBehavior;
//@property UIGravityBehavior *gravityBehavior;
//@property UIDynamicAnimator *dynamicAnimator;
//@property UICollisionBehavior *collisionBehavior;

@property (nonatomic, assign) id currentResponder;

@end


//------------------------------------------------


#pragma mark - notifications

@implementation ViewController

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Test1" object:nil];;
    }
    return self;
}

- (void)receiveNotification: (NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"Test1"])
    {
        [self reload];
    }
}


#pragma mark - view life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    //Ugly keyboard animation
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardWillShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardWillHideNotification object:nil];

    //Scroll opposite
    [self.commentTableView setScrollsToTop:YES];

    //Save tableview frame
    CGRect frame = self.commentTableView.frame;

    //Max made fun of me for this, but I like my scroll bar on the left, so there.
    self.commentTableView.transform = CGAffineTransformMakeRotation(M_PI);
    self.commentTableView.frame = frame;

    self.navigationController.hidesBottomBarWhenPushed = YES;

    [PFUser logOut]; //dev only
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.usernamePlaceHolder = [[NSString alloc] init];


    if (![PFUser currentUser])
    {
        //Create the log in and sign up view controller
        PFLogInViewController *logInViewController = [[PFLogInViewController alloc] init];
        [logInViewController setDelegate:self];
        PFSignUpViewController *signUpViewController = [[PFSignUpViewController alloc] init];
        [signUpViewController setDelegate:self];

        //Assign sign up controller to be displayed from the login controller
        [logInViewController setSignUpController:signUpViewController];

        //Show the log in view controller
        [self presentViewController:logInViewController animated:NO completion:NULL];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self retrieveAuthorsUsernames];
    [self retrieveCommentsFromParse];
    [self.commentTableView reloadData];
}


#pragma mark - send button  CGAFFINE!!!!!

- (IBAction)sendButtonPressed:(UIButton *)sender
{
    [self.view endEditing:YES];

    self.enteredText = self.chatTextFieldOutlet.text;

    //Create Comment Object
    PFObject *newComment = [PFObject objectWithClassName:@"Comment"];

    //this adds the text into parse key textContent
    [newComment setObject:self.enteredText forKey:@"textContent"];

    //This Creates relationship to the user!
    [newComment setObject:[PFUser currentUser] forKey:@"author"];

    //Save comment
    [newComment saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!error) {
            [self retrieveAuthorsUsernames];
            [self retrieveCommentsFromParse];

            [self.commentTableView reloadData];
        }
    }];
    self.chatTextFieldOutlet.text = @"";

    // Create our Installation query
    PFQuery *pushQuery = [PFInstallation query];
    [pushQuery whereKey:@"deviceType" equalTo:@"ios"];

    // Send push notification to query
    [PFPush sendPushMessageToQueryInBackground:pushQuery
                                   withMessage:@"morse code"];



    sender.transform = CGAffineTransformMakeScale(.3f, .3f);
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:2];
    //[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    CGAffineTransform scaleTrans  = CGAffineTransformMakeScale(1.0f, 1.0f);
    CGAffineTransform lefttorightTrans  = CGAffineTransformMakeTranslation(-0.0f,-0.0f);
    sender.transform = CGAffineTransformConcat(scaleTrans, lefttorightTrans);
    [UIView commitAnimations];
}


#pragma mark - Getting from parse

- (void)retrieveCommentsFromParse
{
    //Create a query
    PFQuery *commentQuery = [PFQuery queryWithClassName:@"Comment"];
    [commentQuery includeKey:@"author"];

    [commentQuery orderByDescending:@"createdAt"];

    [commentQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            self.commentsArray = objects;         // Store results
            [self.commentTableView reloadData];   // Reload table
        }
    }];
}

- (void)retrieveAuthorsUsernames
{
    PFQuery *commentQuery = [PFQuery queryWithClassName:@"Comment"];
    [commentQuery orderByDescending:@"createdAt"];

    //Thanks Kevin, it might not be an F16 fighter plane... in due time tho.
    [commentQuery includeKey:@"author"];

    [commentQuery findObjectsInBackgroundWithBlock:^(NSArray *comments, NSError *error) {
        if (!error)
        {
            [[comments.lastObject objectForKey:@"author"] objectForKey:@"username"];

            self.authorsArray = comments;
            self.usernamePlaceHolder = [[comments.firstObject objectForKey:@"author"] objectForKey:@"username"];

            [self.commentTableView reloadData];
        }
    }];
}


#pragma mark - Sign up and log in control methods

//Sent to the delegate to determine whether the log in request should be submitted to the server.
- (BOOL)logInViewController:(PFLogInViewController *)logInController shouldBeginLogInWithUsername:(NSString *)username password:(NSString *)password
{
    //Check if both fields are completed
    if (username && password && username.length != 0 && password.length != 0) {
        return YES; // Begin login process
    }

    [[[UIAlertView alloc] initWithTitle:@"Info missing..."
                                message:@"Fill everything out... genius."
                               delegate:nil
                      cancelButtonTitle:@"Whatevs, stupid phone"
                      otherButtonTitles:nil] show];
    return NO; // Interrupt login process
}

- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

//failed login
- (void)logInViewController:(PFLogInViewController *)logInController didFailToLogInWithError:(NSError *)error
{
    NSLog(@"Failed to log in...");
}

//Sent to the del when the log in screen is dismissed.
- (void)logInViewControllerDidCancelLogIn:(PFLogInViewController *)logInController
{
    [self.navigationController popViewControllerAnimated:YES];
}

//Sent to the del to determine whether the sign up request should be submitted to the server.
- (BOOL)signUpViewController:(PFSignUpViewController *)signUpController shouldBeginSignUp:(NSDictionary *)info
{
    BOOL informationComplete = YES;

    //loop through data
    for (id key in info)
    {
        NSString *field = [info objectForKey:key];
        if (!field || field.length == 0)
        {
            informationComplete = NO;
            break;
        }
    }

    //alert if info missing
    if (!informationComplete)
    {
        [[[UIAlertView alloc] initWithTitle:@"Info missing..."
                                    message:@"Fill everything out... genius."
                                   delegate:nil
                          cancelButtonTitle:@"Whatevs, stupid phone"
                          otherButtonTitles:nil] show];
    }
    return informationComplete;
}


//Sent to the del when a PFUser is signed up.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didSignUpUser:(PFUser *)user {
    [self dismissModalViewControllerAnimated:YES]; // Dismiss the PFSignUpViewController
}

// Sent to the delegate when the sign up attempt fails.
- (void)signUpViewController:(PFSignUpViewController *)signUpController didFailToSignUpWithError:(NSError *)error {
    NSLog(@"Failed to sign up...");
}

// Sent to the delegate when the sign up screen is dismissed.
- (void)signUpViewControllerDidCancelSignUp:(PFSignUpViewController *)signUpController {
    NSLog(@"User dismissed the signUpViewController");
}



#pragma mark - TableView del methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.customCell) {
        self.customCell = [tableView dequeueReusableCellWithIdentifier:@"CommentCell"];
    }

    ///configure cell
    PFObject *message = [self.commentsArray objectAtIndex:indexPath.row];

    [self.customCell.commentTextLabel setText:[message objectForKey:@"textContent"]];

    //layout cell
    [self.customCell layoutIfNeeded];

    //get height mofo
    CGFloat height = [self.customCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    
    return height;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    self.commentTableView.backgroundColor = [UIColor blackColor];
    return self.commentsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomTableViewCell *cell = [[CustomTableViewCell alloc] init];
    PFObject *comment = [self.commentsArray objectAtIndex:indexPath.row];
    PFObject *author = [self.authorsArray objectAtIndex:indexPath.row];

    NSString *temp = [[author objectForKey:@"author"] objectForKey:@"username"];

    if ([temp isEqualToString:[PFUser currentUser].username]) {
        // use the UserCommentCell  (dequeue here)
        cell = [tableView dequeueReusableCellWithIdentifier:@"UserCommentCell"];
    } else {
        // use the Comment Cell (dequeue here)
        cell = [tableView dequeueReusableCellWithIdentifier:@"CommentCell"];
    }

    [cell.commentTextLabel setText:[comment objectForKey:@"textContent"]];

    [cell.usernameLabelInCell setText:[[author objectForKey:@"author"] objectForKey:@"username"]];

    //cell.usernameLabelInCell.textColor = [UIColor orangeColor];
    cell.commentTextLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor blackColor];

    //Avatar pic stuff
    cell.imageInCell.image = [UIImage imageNamed:@"pic4.png"];
    cell.imageInCell.layer.borderWidth = 1.0f;
    cell.imageInCell.layer.cornerRadius = 14.2;
    cell.imageInCell.layer.masksToBounds = YES;
    cell.imageInCell.layer.borderColor = [[UIColor whiteColor] CGColor];

    //Rotate the cell back
    cell.transform = CGAffineTransformMakeRotation(M_PI);
        
    return cell;
}


#pragma mark - Reload stuff

- (void)reload {
    [self retrieveCommentsFromParse];
    [self retrieveAuthorsUsernames];
    [self.commentTableView reloadData];
}


#pragma mark - Method to figure out if scrolling up or down

-(void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{

    if (velocity.y > 0) {
        //[self reload];
        NSLog(@"up");
    }
    if (velocity.y < 0) {
        NSLog(@"down");
        //[self reload];
    }
}

#pragma mark - Keyboard animation stuff, beware... numbers ahead

//new style keyboard animation
- (void) keyboardDidShow:(NSNotification *)notification {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue]];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] intValue]];

    if ([[UIScreen mainScreen] bounds].size.height == 1136) {
        [self.view setFrame:CGRectMake(0, -220, 640, 1120)];
    } else {
        [self.view setFrame:CGRectMake(0, -220, 640, 920)];
    }

    [UIView commitAnimations];
}

//Old style animation
- (void) keyboardDidHide:(NSNotification *)notification {
    if ([[UIScreen mainScreen] bounds].size.height == 1136) {
        [UIView animateWithDuration:0.25 animations:^{
            [self.view setFrame:CGRectMake(0, 0, 640, 1120)];
        }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            [self.view setFrame:CGRectMake(0, 0, 640, 920)];
        }];
    }
}





///future ideas
//- (IBAction)testChannelSubscribeButt:(id)sender {
//    // When users indicate they are Giants fans, we subscribe them to that channel.
//    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
//    [currentInstallation addUniqueObject:@"extra" forKey:@"channels"];
//    [currentInstallation saveInBackground];
//    NSLog(@"etc");
//
//
//    self.dynamicAnimator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
//    self.gravityBehavior = [[UIGravityBehavior alloc] initWithItems:@[sender, self.reloadButt]];
//    self.collisionBehavior = [[UICollisionBehavior alloc] initWithItems:@[self.chatTextFieldOutlet, sender]];
//    //self.collisionBehavior = [[UICollisionBehavior alloc] initWithItems:@[sender]];
//
//    self.collisionBehavior.translatesReferenceBoundsIntoBoundary = NO;
//
//    [self.dynamicAnimator addBehavior:self.gravityBehavior];
//    [self.dynamicAnimator addBehavior:self.collisionBehavior];
//
//    self.gravityBehavior.angle = 6.28;
//
//
//    self.gravityBehavior.magnitude = 6.9;
//}

@end




