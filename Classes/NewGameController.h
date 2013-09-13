
#import <UIKit/UIKit.h>


@interface NewGameController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource> {
    
}
@property (nonatomic, assign) UITableView* tableView;

@end
