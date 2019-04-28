//
//  ViewController.swift
//  Helloworld
//
//  Created by hongyuwang on 2019/4/16.
//  Copyright © 2019 awAlgorithm. All rights reserved.
//

import UIKit

import #replace#

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        let vc = #replace#.SampleViewController();
        vc.view.backgroundColor = .red;
        self.present(vc, animated: true, completion: nil);
    }
}

