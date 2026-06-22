import { Test2 } from "./Test2";

export class Test {
    _number: number
    _text: string
    _test2: Test2
    constructor() {
        this._test2 = new Test2();       
        this._number = this._test2.DoAction();
        this._text = this._test2.DoAnotherAction();
    }
}