class Program {

    int absDiff(int x,int y){
        if(x>y)
            return x-y;
        else
            return y-x;
    }

    int main() {
        Print "---------Multi-argument Function--------------\n";
        int a=9;
        int b=10;
        int c=3;
        int d=7;
        if(absDiff(a,b) > absDiff(c,d)){
            Print "|a-b| > |c-d|" + endl;
        }else
            Print "|a-b| < |c-d|" + endl;
    }
}