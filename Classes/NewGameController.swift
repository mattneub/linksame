

import UIKit
import Swift

private let cellid = "Cell"

class NewGameController : UIViewController {
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
        
        // on iPhone, no choice of size, so no table view
        
        let tv = UITableView(frame:CGRectMake(0,0,320,350), style:.Grouped)
        
        if !onPhone {
            // unfortunately I have not found any way except to size manually like this by experimentation
            v.addSubview(tv)
            tv.dataSource = self
            tv.delegate = self
            tv.bounces = false
            tv.scrollEnabled = false
            tv.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellid)
            self.tableView = tv
        }
        
        let pv = UIPickerView(frame:CGRectMake(0,0,320,160)) // on iPad, not really
        
        pv.dataSource = self
        pv.delegate = self
        pv.sizeToFit() // a picker view has its own natural size
        if !onPhone {
            pv.frame.origin.y = tv.frame.size.height
        }
        v.addSubview(pv)
        pv.showsSelectionIndicator = true
        pv.selectRow(ud.integerForKey(Default.LastStage), inComponent: 0, animated: false)

        self.preferredContentSize = CGSizeMake(320, tv.frame.size.height + pv.frame.size.height)
    }
}

extension NewGameController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return Default.Size
        case 1:
            return Default.Style
        default:
            return nil
        }
    }
    
    func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 3
        case 1:
            return 2
        default:
            return 0
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellid, forIndexPath:indexPath) as! UITableViewCell
        
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            cell.textLabel!.text = Sizes.sizes()[row]
        case 1:
            cell.textLabel!.text = Styles.styles()[row]
        default:
            cell.textLabel!.text = "" // throwaway
        }
        
        cell.accessoryType = .None
        if contains([ud.stringForKey(Default.Style), ud.stringForKey(Default.Size)], {$0 == cell.textLabel!.text}) {
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
