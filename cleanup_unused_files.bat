@echo off
echo ========================================
echo  SMART CITY - CLEANUP UNUSED FILES
echo ========================================
echo.

echo Removing unused files from root directory...

REM Root directory unused files
del /f /q "forgot_old.txt" 2>nul
del /f /q "forgot_password_update.txt" 2>nul
del /f /q "data.txt" 2>nul
del /f /q "simple_ai_test.py" 2>nul
del /f /q "test_ai_chat.py" 2>nul
del /f /q "test_enhanced_ai.py" 2>nul
del /f /q "colab_setup.py" 2>nul
del /f /q "get_subcategories.py" 2>nul
del /f /q "get_supabase_ipv4.py" 2>nul
del /f /q "upload_images_interactive.py" 2>nul
del /f /q "upload_to_cloudinary.py" 2>nul
del /f /q "upload_to_colab.py" 2>nul
del /f /q "train_llm.py" 2>nul
del /f /q "train_llm_colab.py" 2>nul
del /f /q "LLM_Training_Colab.ipynb" 2>nul
del /f /q ".lock" 2>nul
del /f /q "CACHEDIR.TAG" 2>nul

echo Removing unused cityfix_llm deployment files...
cd cityfix_llm
del /f /q "deploy_fix.py" 2>nul
del /f /q "deploy_now.py" 2>nul
del /f /q "deploy_space.py" 2>nul
del /f /q "deploy_to_hf.py" 2>nul
del /f /q "deploy.bat" 2>nul
del /f /q "final_deploy.py" 2>nul
del /f /q "fix_python_version.bat" 2>nul
del /f /q "fix_python_version.py" 2>nul
del /f /q "fix_space.py" 2>nul
del /f /q "hf_login.py" 2>nul
del /f /q "list_space_files.py" 2>nul
del /f /q "quick_deploy.py" 2>nul
del /f /q "upload_app.py" 2>nul
del /f /q "upload_model.py" 2>nul
del /f /q "upload_readme.py" 2>nul
del /f /q "upload_simple_model.py" 2>nul
del /f /q "verify_deployment.py" 2>nul
del /f /q "verify_files.py" 2>nul
del /f /q "verify_model.py" 2>nul
del /f /q "test_api_simple.py" 2>nul
del /f /q "test_api.py" 2>nul
del /f /q "test_endpoints.py" 2>nul
del /f /q "test_enhanced.py" 2>nul
del /f /q "train_colab.py" 2>nul
del /f /q "train.py" 2>nul
del /f /q "generate_complex_data.py" 2>nul
del /f /q "HOW_TO_GET_TOKEN.txt" 2>nul
del /f /q "ENHANCED_FEATURES_GUIDE.txt" 2>nul
cd ..

echo Removing unused complaints test files...
cd complaints
del /f /q "test_cityfix.py" 2>nul
del /f /q "tests.py" 2>nul
del /f /q "forms.py" 2>nul
del /f /q "enhanced_ai_views.py" 2>nul
del /f /q "step_by_step_ai.py" 2>nul
cd ..

echo Removing unused Flutter app files...
cd smartcity_application
del /f /q "flutter_01.log" 2>nul
del /f /q "janhelp.iml" 2>nul

cd android
del /f /q "hs_err_pid18364.log" 2>nul
del /f /q "replay_pid18364.log" 2>nul
del /f /q "janhelp_android.iml" 2>nul
cd ..

cd test
del /f /q "widget_test.dart" 2>nul
cd ..

cd ..

echo Removing unused template duplicates...
cd templates
del /f /q "dashboard.html" 2>nul
del /f /q "department_dashboard.html" 2>nul
del /f /q "ai_chat_test.html" 2>nul
del /f /q "dynamic_fields_test.html" 2>nul
del /f /q "translation_test.html" 2>nul
cd ..

echo Removing duplicate template files in complaints folder...
cd complaints\templates
del /f /q "submit_complaint.html" 2>nul
del /f /q "super_admin_add_city.html" 2>nul
del /f /q "super_admin_add_department.html" 2>nul
del /f /q "super_admin_add_state.html" 2>nul
del /f /q "super_admin_base.html" 2>nul
del /f /q "super_admin_categories.html" 2>nul
del /f /q "super_admin_city_admins.html" 2>nul
del /f /q "super_admin_complaint_detail.html" 2>nul
del /f /q "super_admin_departments.html" 2>nul
del /f /q "super_admin_edit_category.html" 2>nul
del /f /q "super_admin_edit_city_admin.html" 2>nul
del /f /q "super_admin_edit_city.html" 2>nul
del /f /q "super_admin_edit_department.html" 2>nul
del /f /q "super_admin_edit_state.html" 2>nul
del /f /q "super_admin_review.html" 2>nul
del /f /q "super_admin_user_detail.html" 2>nul
del /f /q "super_admin_users.html" 2>nul
del /f /q "user_dashboard.html" 2>nul
cd ..\..

echo Removing unused .github folders...
rmdir /s /q ".github" 2>nul
rmdir /s /q ".qodo" 2>nul
rmdir /s /q ".zencoder" 2>nul
rmdir /s /q ".zenflow" 2>nul

echo Removing unused Lib folder...
rmdir /s /q "Lib" 2>nul

echo.
echo ========================================
echo  CLEANUP COMPLETE!
echo ========================================
echo.
echo Removed:
echo - Test files (test_*.py, *_test.*)
echo - Old/backup files (forgot_old.txt, etc.)
echo - Deployment scripts (deploy_*.py, upload_*.py)
echo - Training scripts (train_*.py, colab_*.py)
echo - Duplicate templates
echo - Unused folders (.github, .qodo, .zencoder, .zenflow, Lib)
echo - Log files (*.log)
echo - Temporary files (.lock, CACHEDIR.TAG)
echo.
pause
