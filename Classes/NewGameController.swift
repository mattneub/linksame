

import UIKit
import Swift

private let cellid = "Cell"

class NewGameController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var tableView : UITableView!
    
    init () {
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = UIRectEdge.None
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        let v = self.view
        v.backgroundColor = UIColor.whiteColor()
        
        // unfortunately I have not found any way except to size manually like this by experimentation
        let tableHeight : CGFloat = (onPhone ? 120 : 300)
        let tv = UITableView(frame:CGRectMake(0,0,320,tableHeight), style:.Grouped)
        
        v.addSubview(tv)
        tv.dataSource = self
        tv.delegate = self
        tv.bounces = false
        tv.scrollEnabled = false
        tv.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellid)
        self.tableView = tv
        tv.translatesAutoresizingMaskIntoConstraints = false
        v.addConstraints(
            NSLayoutConstraint.constraintsWithVisualFormat("H:|[tv]|", options: [], metrics: nil, views: ["tv":tv])
        )
        v.addConstraints(
            NSLayoutConstraint.constraintsWithVisualFormat("V:|-(0)-[tv(tableHeight)]", options: [],
                metrics: ["tableHeight":tableHeight],
                views: ["tv":tv])
        )
        
        let pv = UIPickerView()
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.dataSource = self
        pv.delegate = self
        v.addSubview(pv)
        v.addConstraints(
            NSLayoutConstraint.constraintsWithVisualFormat("H:|[pv]|", options: [], metrics: nil, views: ["pv":pv])
        )
        v.addConstraints(
            NSLayoutConstraint.constraintsWithVisualFormat("V:[tv]-(0)-[pv]", options: [],
                metrics: nil,
                views: ["tv":tv, "pv":pv])
        )
        pv.showsSelectionIndicator = true
        pv.selectRow(ud.integerForKey(Default.LastStage), inComponent: 0, animated: false)

        self.preferredContentSize = CGSizeMake(320, tv.frame.size.height + pv.frame.size.height)
    }
}

extension NewGameController {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return onPhone ? 1 : 2 // on iPhone, omit second (Size) section: there is just one size
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return Default.Style
        case 1:
            return Default.Size
        default:
            return nil
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 3
        default:
            return 0
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellid, forIndexPath:indexPath)
        
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            cell.textLabel!.text = Styles.styles()[row]
        case 1:
            cell.textLabel!.text = Sizes.sizes()[row]
        default:
            cell.textLabel!.text = "" // throwaway
        }
        
        cell.accessoryType = .None
        if [ud.stringForKey(Default.Style), ud.stringForKey(Default.Size)].contains({$0 == cell.textLabel!.text}) {
            cell.accessoryType = .Checkmark
        }

        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let setting = tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.text {
            ud.setObject(setting, forKey: self.tableView(tableView, titleForHeaderInSection:indexPath.section)!)
            self.tableView.reloadData()
        }
    }
}

extension NewGameController : UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 9
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row+1) Stage" + ( row > 0 ? "s" : "")
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        ud.setInteger(row, forKey:Default.LastStage)
    }
    
    func pickerView(pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 35
    }



}
