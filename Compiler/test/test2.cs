class Program {
    int[100] arr;

    int findMin(int size){
        int min = 100000;
        for(int i=0;i<size;i++){
            if(arr[i]<min)
                min=arr[i];
        }
        return min;
    }

    int findMax(int size){
        int max = -100000;
        for(int i=0;i<size;i++){
            if(arr[i]>max)
                max=arr[i];
        }
        return max;
    }

    int main() {
        Print "-------Array Input Program-------" + endl;
        Print "Enter Size of Array: ";
        int size = scan();
        for(int i=0;i<size;i++){
            Print "Enter element i=" + i + " ";
            arr[i] = scan();
        }
        int minimum = findMin(size);
        Print "Minimum is " + minimum + endl;
        int maximum = findMax(size);
        Print "Maximum is " + maximum + endl;
        return 0;
    }
}