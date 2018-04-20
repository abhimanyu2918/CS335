 class Program{
    int main(){ 
        Print "------------Switch---------------\n";
        Print "Enter a integer (>0): ";
        int a=scan();
        switch(a){
            case 1:
            case 2:
                Print "value of a is: " + a  + " < 3" + endl;
            case 3:
                Print "Value of a is: " + a + " = 3\n";  
            default:
                Print "Value of a is: " + a + " > 3\n";  
        }
        return 0;
    }
}
