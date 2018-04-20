class Program {
    int d,l,m,p;
    int fact(int y) {
        if (y == 1) {
            return 1;
        }
        return y*fact(y-1) ;        
    }
    int doublefact(int x) {
        return d*fact(x);
    }
    int main() {
        d=2;
        Print "------------FACTORIAL PROGRAM--------------" + endl;
        Print "Enter number: ";
        int y = scan();
        int x = doublefact(y);
        Print "Double Factorial of " + y + " is " + x + endl;
        Print "------------END OF PROGRAM-----------------" + endl;
        return 0;
    }
}