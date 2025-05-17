import dashscope
import inspect

# Print the dashscope version
print(f"DashScope version: {dashscope.__version__ if hasattr(dashscope, '__version__') else 'unknown'}")

# Print all modules and attributes in dashscope
print("\nAvailable attributes in dashscope:")
for name in dir(dashscope):
    if not name.startswith('__'):
        try:
            attr = getattr(dashscope, name)
            attr_type = type(attr).__name__
            print(f"  - {name}: {attr_type}")
            
            # If it's a module, print its contents
            if attr_type == 'module':
                print(f"    Contents of {name} module:")
                for subname in dir(attr):
                    if not subname.startswith('__'):
                        print(f"      - {subname}")
        except Exception as e:
            print(f"  - {name}: Error accessing - {str(e)}")

# Try to find any OCR-related functionality
print("\nSearching for OCR-related functionality:")
for name in dir(dashscope):
    if not name.startswith('__'):
        try:
            attr = getattr(dashscope, name)
            # Check if the name or docstring contains 'ocr' or 'vision'
            attr_doc = attr.__doc__ or ""
            if 'ocr' in name.lower() or 'vision' in name.lower() or 'ocr' in attr_doc.lower() or 'vision' in attr_doc.lower():
                print(f"  Found potential OCR-related item: {name}")
                print(f"  Documentation: {attr_doc[:200]}...")
                
                # If it's a callable, print its signature
                if callable(attr):
                    try:
                        sig = inspect.signature(attr)
                        print(f"  Signature: {name}{sig}")
                    except:
                        print(f"  (Unable to get signature for {name})")
        except:
            pass