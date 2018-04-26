class Program{
int[10] arr;

int binarySearch(int l, int r, int x)
{
   if (r >= l)
   {
        int mid = l + (r - l)/2;
 
        // If the element is present at the middle 
        // itself
        if (arr[mid] == x)  
            return mid;
 
        // If element is smaller than mid, then 
        // it can only be present in left subarray
        if (arr[mid] > x) 
            return binarySearch(l, mid-1, x);
 
        // Else the element can only be present
        // in right subarray
        return binarySearch(mid+1, r, x);
   }
 
   // We reach here when element is not 
   // present in array
   return -1;
}
 
int main()
{
	arr[0] = 2;
	arr[1] = 3;
	arr[2] = 4;
	arr[3] = 10;
	arr[4] = 40;
	arr[5] = 50;
	arr[6] = 55;
	arr[7] = 60;
	arr[8] = 80;
	arr[9] = 101;
   int n = 10;
   Print arr[0] + endl;
   Print "----------Binary Search---------" + endl;
   Print "Array elements: " + endl;
   for(int i=0;i<n;i++){
   	Print arr[i] + " ";
   }
   Print endl;
   Print "Enter x: ";
   int x = scan();
   int result = binarySearch(0, n-1, x);
   if(result==-1)
   	Print x + " not found" + endl;
   else 
    Print x + " found" + endl;
   return 0;
}
}