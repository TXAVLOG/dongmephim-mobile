; *** Inno Setup version 6.5.0+ Vietnamese messages ***
;
; Tác giả: TXA TEAM
; Phiên bản: 2026.07.10

[LangOptions]
LanguageName=Vietnamese
LanguageID=$042A
LanguageCodePage=1258

[Messages]

; *** Application titles
SetupAppTitle=Cài đặt
SetupWindowTitle=Cài đặt - %1
UninstallAppTitle=Gỡ cài đặt
UninstallAppFullTitle=Gỡ cài đặt %1

; *** Misc. common
InformationTitle=Thông tin
ConfirmTitle=Xác nhận
ErrorTitle=Lỗi

; *** SetupLdr messages
SetupLdrStartupMessage=Chương trình này sẽ cài đặt %1. Bạn có muốn tiếp tục không?
LdrCannotCreateTemp=Không thể tạo tệp tạm. Đã hủy cài đặt
LdrCannotExecTemp=Không thể thực thi tệp trong thư mục tạm. Đã hủy cài đặt
HelpTextNote=

; *** Startup error messages
LastErrorMessage=%1.%n%nLỗi %2: %3
SetupFileMissing=Tệp %1 bị thiếu trong thư mục cài đặt. Vui lòng khắc phục sự cố hoặc lấy bản sao mới của chương trình.
SetupFileCorrupt=Các tệp cài đặt bị hỏng. Vui lòng lấy bản sao mới của chương trình.
SetupFileCorruptOrWrongVer=Các tệp cài đặt bị hỏng hoặc không tương thích với phiên bản Setup này. Vui lòng khắc phục sự cố hoặc lấy bản sao mới của chương trình.
InvalidParameter=Tham số không hợp lệ được truyền trên dòng lệnh:%n%n%1
SetupAlreadyRunning=Setup đang chạy.
WindowsVersionNotSupported=Chương trình này không hỗ trợ phiên bản Windows mà máy tính của bạn đang chạy.
WindowsServicePackRequired=Chương trình này yêu cầu %1 Service Pack %2 trở lên.
NotOnThisPlatform=Chương trình này sẽ không chạy trên %1.
OnlyOnThisPlatform=Chương trình này phải được chạy trên %1.
OnlyOnTheseArchitectures=Chương trình này chỉ có thể được cài đặt trên các phiên bản Windows được thiết kế cho các kiến trúc bộ xử lý sau:%n%n%1
WinVersionTooLowError=Chương trình này yêu cầu %1 phiên bản %2 trở lên.
WinVersionTooHighError=Chương trình này không thể được cài đặt trên %1 phiên bản %2 trở lên.
AdminPrivilegesRequired=Bạn phải đăng nhập với tư cách quản trị viên khi cài đặt chương trình này.
PowerUserPrivilegesRequired=Bạn phải đăng nhập với tư cách quản trị viên hoặc thành viên nhóm Power Users khi cài đặt chương trình này.
SetupAppRunningError=Setup đã phát hiện rằng %1 hiện đang chạy.%n%nVui lòng đóng tất cả các cửa sổ của chương trình, sau đó nhấp OK để tiếp tục, hoặc Hủy để thoát.
UninstallAppRunningError=Gỡ cài đặt đã phát hiện rằng %1 hiện đang chạy.%n%nVui lòng đóng tất cả các cửa sổ của chương trình, sau đó nhấp OK để tiếp tục, hoặc Hủy để thoát.

; *** Startup questions
PrivilegesRequiredOverrideTitle=Chọn chế độ cài đặt
PrivilegesRequiredOverrideInstruction=Chọn chế độ cài đặt
PrivilegesRequiredOverrideText1=%1 có thể được cài đặt cho tất cả người dùng (yêu cầu quyền quản trị viên), hoặc chỉ cho bạn.
PrivilegesRequiredOverrideText2=%1 có thể được cài đặt chỉ cho bạn, hoặc cho tất cả người dùng (yêu cầu quyền quản trị viên).
PrivilegesRequiredOverrideAllUsers=Cài đặt cho &tất cả người dùng
PrivilegesRequiredOverrideAllUsersRecommended=Cài đặt cho &tất cả người dùng (khuyến nghị)
PrivilegesRequiredOverrideCurrentUser=Cài đặt chỉ cho &tôi
PrivilegesRequiredOverrideCurrentUserRecommended=Cài đặt chỉ cho &tôi (khuyến nghị)

; *** Misc. errors
ErrorCreatingDir=Setup không thể tạo thư mục "%1"
ErrorTooManyFilesInDir=Không thể tạo tệp trong thư mục "%1" vì chứa quá nhiều tệp

; *** Setup common messages
ExitSetupTitle=Thoát Setup
ExitSetupMessage=Setup chưa hoàn thành. Nếu bạn thoát bây giờ, chương trình sẽ không được cài đặt.%n%nBạn có thể chạy lại Setup vào lúc khác để hoàn tất cài đặt.%n%nThoát Setup?
AboutSetupMenuItem=&Thông tin về Setup...
AboutSetupTitle=Thông tin về Setup
AboutSetupMessage=%1 phiên bản %2%n%3%n%nTrang chủ:%n%4
AboutSetupNote=
TranslatorNote=Bản dịch Việt bởi TXA TEAM

; *** Buttons
ButtonBack=< &Quay lại
ButtonNext=&Tiếp theo >
ButtonInstall=&Cài đặt
ButtonOK=OK
ButtonCancel=Hủy
ButtonYes=&Có
ButtonYesToAll=Có cho &tất cả
ButtonNo=&Không
ButtonNoToAll=Kh&ông cho tất cả
ButtonFinish=&Hoàn thành
ButtonBrowse=&Duyệt...
ButtonWizardBrowse=D&uyệt...
ButtonNewFolder=&Tạo thư mục mới

; *** "Select Language" dialog messages
SelectLanguageTitle=Chọn ngôn ngữ Setup
SelectLanguageLabel=Chọn ngôn ngữ sử dụng trong quá trình cài đặt.

; *** Common wizard text
ClickNext=Nhấp Tiếp theo để tiếp tục, hoặc Hủy để thoát Setup.
BeveledLabel=
BrowseDialogTitle=Duyệt thư mục
BrowseDialogLabel=Chọn một thư mục trong danh sách bên dưới, sau đó nhấp OK.
NewFolderName=Thư mục mới

; *** "Welcome" wizard page
WelcomeLabel1=Chào mừng đến với Trình cài đặt [name]
WelcomeLabel2=Chương trình sẽ cài đặt [name/ver] trên máy tính của bạn.%n%nKhuyến nghị bạn đóng tất cả các ứng dụng khác trước khi tiếp tục.

; *** "Password" wizard page
WizardPassword=Mật khẩu
PasswordLabel1=Cài đặt này được bảo vệ bằng mật khẩu.
PasswordLabel3=Vui lòng nhập mật khẩu, sau đó nhấp Tiếp theo để tiếp tục. Mật khẩu phân biệt chữ hoa chữ thường.
PasswordEditLabel=&Mật khẩu:
IncorrectPassword=Mật khẩu bạn nhập không chính xác. Vui lòng thử lại.

; *** "License Agreement" wizard page
WizardLicense=Thỏa thuận cấp phép
LicenseLabel=Vui lòng đọc thông tin quan trọng sau trước khi tiếp tục.
LicenseLabel3=Vui lòng đọc Thỏa thuận cấp phép sau. Bạn phải chấp nhận các điều khoản của thỏa thuận này trước khi tiếp tục cài đặt.
LicenseAccepted=Tôi &chấp nhận thỏa thuận
LicenseNotAccepted=Tôi &không chấp nhận thỏa thuận

; *** "Information" wizard pages
WizardInfoBefore=Thông tin
InfoBeforeLabel=Vui lòng đọc thông tin quan trọng sau trước khi tiếp tục.
InfoBeforeClickLabel=Khi bạn sẵn sàng tiếp tục Setup, nhấp Tiếp theo.
WizardInfoAfter=Thông tin
InfoAfterLabel=Vui lòng đọc thông tin quan trọng sau trước khi tiếp tục.
InfoAfterClickLabel=Khi bạn sẵn sàng tiếp tục Setup, nhấp Tiếp theo.

; *** "User Information" wizard page
WizardUserInfo=Thông tin người dùng
UserInfoDesc=Vui lòng nhập thông tin của bạn.
UserInfoName=&Tên người dùng:
UserInfoOrg=&Tổ chức:
UserInfoSerial=&Số sê-ri:
UserInfoNameRequired=Bạn phải nhập tên.

; *** "Select Destination Location" wizard page
WizardSelectDir=Chọn vị trí cài đặt
SelectDirDesc=[name] nên được cài đặt ở đâu?
SelectDirLabel3=Setup sẽ cài đặt [name] vào thư mục sau.
SelectDirBrowseLabel=Để tiếp tục, nhấp Tiếp theo. Nếu bạn muốn chọn thư mục khác, nhấp Duyệt.
DiskSpaceGBLabel=Ít nhất [gb] GB dung lượng trống là bắt buộc.
DiskSpaceMBLabel=Ít nhất [mb] MB dung lượng trống là bắt buộc.
CannotInstallToNetworkDrive=Setup không thể cài đặt vào ổ đĩa mạng.
CannotInstallToUNCPath=Setup không thể cài đặt vào đường dẫn UNC.
InvalidPath=Bạn phải nhập đường dẫn đầy đủ với chữ cái ổ đĩa; ví dụ:%n%nC:\APP%n%nhỏ đường dẫn UNC dưới dạng:%n%n\\server\share
InvalidDrive=Ổ đĩa hoặc UNC share bạn chọn không tồn tại hoặc không thể truy cập. Vui lòng chọn ổ khác.
DiskSpaceWarningTitle=Không đủ dung lượng trống
DiskSpaceWarning=Setup yêu cầu ít nhất %1 KB dung lượng trống để cài đặt, nhưng ổ đĩa đã chọn chỉ có %2 KB.%n%nBạn có muốn tiếp tục không?
DirNameTooLong=Tên hoặc đường dẫn thư mục quá dài.
InvalidDirName=Tên thư mục không hợp lệ.
BadDirName32=Tên thư mục không được chứa bất kỳ ký tự nào sau:%n%n%1
DirExistsTitle=Thư mục đã tồn tại
DirExists=Thư mục:%n%n%1%n%ndã tồn tại. Bạn có muốn cài đặt vào thư mục này không?
DirDoesntExistTitle=Thư mục không tồn tại
DirDoesntExist=Thư mục:%n%n%1%n%nkhông tồn tại. Bạn có muốn tạo thư mục này không?

; *** "Select Components" wizard page
WizardSelectComponents=Chọn thành phần
SelectComponentsDesc=Những thành phần nào nên được cài đặt?
SelectSegmentsLabel2=Chọn các thành phần bạn muốn cài đặt; bỏ chọn các thành phần bạn không muốn cài đặt. Nhấp Tiếp theo khi bạn sẵn sàng.
FullInstallation=Cài đặt đầy đủ
CompactInstallation=Cài đặt gọn nhẹ
CustomInstallation=Cài đặt tùy chỉnh
NoUninstallWarningTitle=Thành phần đã tồn tại
NoUninstallWarning=Setup đã phát hiện rằng các thành phần sau đã được cài đặt trên máy tính của bạn:%n%n%1%n%nBỏ chọn các thành phần này sẽ không gỡ cài đặt chúng.%n%nBạn có muốn tiếp tục không?
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceGBLabel=Lựa chọn hiện tại yêu cầu ít nhất [gb] GB dung lượng trống.
ComponentsDiskSpaceMBLabel=Lựa chọn hiện tại yêu cầu ít nhất [mb] MB dung lượng trống.

; *** "Select Additional Tasks" wizard page
WizardSelectTasks=Chọn tác vụ bổ sung
SelectTasksDesc=Những tác vụ bổ sung nào nên được thực hiện?
SelectTasksLabel2=Chọn các tác vụ bổ sung mà bạn muốn Setup thực hiện trong khi cài đặt [name], sau đó nhấp Tiếp theo.

; *** "Select Start Menu Folder" wizard page
WizardSelectProgramGroup=Chọn thư mục Menu Start
SelectStartMenuFolderDesc=Setup nên đặt biểu tượng tắt của chương trình ở đâu?
SelectStartMenuFolderLabel3=Setup sẽ tạo các biểu tượng tắt trong thư mục Menu Start sau.
SelectStartMenuFolderBrowseLabel=Để tiếp tục, nhấp Tiếp theo. Nếu bạn muốn chọn thư mục khác, nhấp Duyệt.
MustEnterGroupName=Bạn phải nhập tên thư mục.
GroupNameTooLong=Tên hoặc đường dẫn thư mục quá dài.
InvalidGroupName=Tên thư mục không hợp lệ.
BadGroupName=Tên thư mục không được chứa bất kỳ ký tự nào sau:%n%n%1
NoProgramGroupCheck2=&Không tạo thư mục Menu Start

; *** "Ready to Install" wizard page
WizardReady=Sẵn sàng cài đặt
ReadyLabel1=Setup đã sẵn sàng bắt đầu cài đặt [name] trên máy tính của bạn.
ReadyLabel2a=Nhấp Cài đặt để tiếp tục, hoặc nhấp Quay lại nếu bạn muốn xem lại hoặc thay đổi bất kỳ cài đặt nào.
ReadyLabel2b=Nhấp Cài đặt để tiếp tục.
ReadyMemoUserInfo=Thông tin người dùng:
ReadyMemoDir=Vị trí cài đặt:
ReadyMemoType=Loại cài đặt:
ReadyMemoComponents=Các thành phần đã chọn:
ReadyMemoGroup=Thư mục Menu Start:
ReadyMemoTasks=Tác vụ bổ sung:

; *** TDownloadWizardPage wizard page and DownloadTemporaryFile
DownloadingLabel2=Đang tải xuống...
ButtonStopDownload=&Dừng tải xuống
StopDownload=Bạn có chắc chắn muốn dừng tải xuống không?
ErrorDownloadAborted=Đã hủy tải xuống
ErrorDownloadFailed=Tải xuống thất bại: %1 %2
ErrorSizeFailed=Lấy kích thước thất bại: %1 %2
ErrorProgress=Tiến trình không hợp lệ: %1 / %2
ErrorFileSize=Kích thước tệp không hợp lệ: mong đợi %1, tìm thấy %2

; *** TExtractionWizardPage wizard page and ExtractArchive
ExtractingLabel=Đang trích xuất tệp...
ButtonStopExtraction=&Dừng trích xuất
StopExtraction=Bạn có chắc chắn muốn dừng trích xuất không?
ErrorExtractionAborted=Đã hủy trích xuất
ErrorExtractionFailed=Trích xuất thất bại: %1

; *** Archive extraction failure details
ArchiveIncorrectPassword=Mật khẩu không chính xác
ArchiveIsCorrupted=Archive bị hỏng
ArchiveUnsupportedFormat=Định dạng archive không được hỗ trợ

; *** "Preparing to Install" wizard page
WizardPreparing=Đang chuẩn bị cài đặt
PreparingDesc=Setup đang chuẩn bị cài đặt [name] trên máy tính của bạn.
PreviousInstallNotCompleted=Việc cài đặt/gỡ bỏ chương trình trước đó chưa hoàn thành. Bạn sẽ cần khởi động lại máy tính để hoàn tất việc đó.%n%nSau khi khởi động lại, hãy chạy Setup lại để hoàn tất cài đặt [name].
CannotContinue=Setup không thể tiếp tục. Vui lòng nhấp Hủy để thoát.
ApplicationsFound=Các ứng dụng sau đang sử dụng tệp cần được Setup cập nhật. Khuyến nghị bạn cho phép Setup tự động đóng các ứng dụng này.
ApplicationsFound2=Các ứng dụng sau đang sử dụng tệp cần được Setup cập nhật. Khuyến nghị bạn cho phép Setup tự động đóng các ứng dụng này. Sau khi cài đặt xong, Setup sẽ cố gắng khởi động lại các ứng dụng.
CloseApplications=&Tự động đóng các ứng dụng
DontCloseApplications=&Không đóng các ứng dụng
ErrorCloseApplications=Setup không thể tự động đóng tất cả ứng dụng. Khuyến nghị bạn đóng tất cả ứng dụng đang sử dụng tệp cần được Setup cập nhật trước khi tiếp tục.
PrepareToInstallNeedsRestart=Setup cần khởi động lại máy tính. Sau khi khởi động lại, hãy chạy Setup lại để hoàn tất cài đặt [name].%n%nBạn có muốn khởi động lại không?

; *** "Installing" wizard page
WizardInstalling=Đang cài đặt
InstallingLabel=Vui lòng đợi trong khi Setup cài đặt [name] trên máy tính của bạn.

; *** "Setup Completed" wizard page
FinishedHeadingLabel=Hoàn thành Trình cài đặt [name]
FinishedLabelNoIcons=Setup đã hoàn tất cài đặt [name] trên máy tính của bạn.
FinishedLabel=Setup đã hoàn tất cài đặt [name] trên máy tính của bạn. Ứng dụng có thể được khởi động bằng cách chọn các biểu tượng tắt đã cài đặt.
ClickFinish=Nhấp Hoàn thành để thoát Setup.
FinishedRestartLabel=Để hoàn tất cài đặt [name], Setup cần khởi động lại máy tính. Bạn có muốn khởi động lại không?
FinishedRestartMessage=Để hoàn tất cài đặt [name], Setup cần khởi động lại máy tính.%n%nBạn có muốn khởi động lại không?
ShowReadmeCheck=Có, tôi muốn xem tệp README
YesRadio=&Có, khởi động lại máy tính ngay
NoRadio=&Không, tôi sẽ khởi động lại sau
; used for example as 'Run MyProg.exe'
RunEntryExec=Chạy %1
; used for example as 'View Readme.txt'
RunEntryShellExec=Xem %1

; *** "Setup Needs the Next Disk" stuff
ChangeDiskTitle=Setup cần đĩa tiếp theo
SelectDiskLabel2=Vui lòng đưa Đĩa %1 vào và nhấp OK.%n%nNếu các tệp trên đĩa này có thể được tìm thấy trong thư mục khác với thư mục hiển thị bên dưới, hãy nhập đường dẫn đúng hoặc nhấp Duyệt.
PathLabel=&Đường dẫn:
FileNotInDir2=Tệp "%1" không thể được tìm thấy trong "%2". Vui lòng đưa đĩa đúng vào hoặc chọn thư mục khác.
SelectDirectoryLabel=Vui lòng chỉ định vị trí của đĩa tiếp theo.

; *** Installation phase messages
SetupAborted=Setup chưa hoàn thành.%n%nVui lòng khắc phục sự cố và chạy lại Setup.
AbortRetryIgnoreSelectAction=Chọn hành động
AbortRetryIgnoreRetry=&Thử lại
AbortRetryIgnoreIgnore=&Bỏ qua lỗi và tiếp tục
AbortRetryIgnoreCancel=Hủy cài đặt
RetryCancelSelectAction=Chọn hành động
RetryCancelRetry=&Thử lại
RetryCancelCancel=Hủy

; *** Installation status messages
StatusClosingApplications=Đang đóng ứng dụng...
StatusCreateDirs=Đang tạo thư mục...
StatusExtractFiles=Đang trích xuất tệp...
StatusDownloadFiles=Đang tải xuống...
StatusCreateIcons=Đang tạo biểu tượng tắt...
StatusCreateIniEntries=Đang tạo mục INI...
StatusCreateRegistryEntries=Đang tạo mục registry...
StatusRegisterFiles=Đang đăng ký tệp...
StatusSavingUninstall=Đang lưu thông tin gỡ cài đặt...
StatusRunProgram=Đang hoàn tất cài đặt...
StatusRestartingApplications=Đang khởi động lại ứng dụng...
StatusRollback=Đang hoàn tác thay đổi...

; *** Misc. errors
ErrorInternal2=Lỗi nội bộ: %1
ErrorFunctionFailedNoCode=%1 thất bại
ErrorFunctionFailed=%1 thất bại; mã %2
ErrorFunctionFailedWithMessage=%1 thất bại; mã %2.%n%3
ErrorExecutingProgram=Không thể thực thi tệp:%n%1

; *** Registry errors
ErrorRegOpenKey=Lỗi mở khóa registry:%n%1\%2
ErrorRegCreateKey=Lỗi tạo khóa registry:%n%1\%2
ErrorRegWriteKey=Lỗi ghi vào khóa registry:%n%1\%2

; *** INI errors
ErrorIniEntry=Lỗi tạo mục INI trong tệp "%1".

; *** File copying errors
FileAbortRetryIgnoreSkipNotRecommended=&Bỏ qua tệp này (không khuyến nghị)
FileAbortRetryIgnoreIgnoreNotRecommended=&Bỏ qua lỗi và tiếp tục (không khuyến nghị)
SourceIsCorrupted=Tệp nguồn bị hỏng
SourceDoesntExist=Tệp nguồn "%1" không tồn tại
SourceVerificationFailed=Xác minh tệp nguồn thất bại: %1
VerificationSignatureDoesntExist=Tệp chữ ký "%1" không tồn tại
VerificationSignatureInvalid=Tệp chữ ký "%1" không hợp lệ
VerificationKeyNotFound=Tệp chữ ký "%1" sử dụng khóa không xác định
VerificationFileNameIncorrect=Tên tệp không chính xác
VerificationFileTagIncorrect=Thẻ tệp không chính xác
VerificationFileSizeIncorrect=Kích thước tệp không chính xác
VerificationFileHashIncorrect=Hash tệp không chính xác
ExistingFileReadOnly2=Tệp hiện tại không thể được thay thế vì nó được đánh dấu chỉ đọc.
ExistingFileReadOnlyRetry=&Xóa thuộc tính chỉ đọc và thử lại
ExistingFileReadOnlyKeepExisting=&Giữ tệp hiện tại
ErrorReadingExistingDest=Đã xảy ra lỗi khi đọc tệp hiện tại:
FileExistsSelectAction=Chọn hành động
FileExists2=Tệp đã tồn tại.
FileExistsOverwriteExisting=&Ghi đè tệp hiện tại
FileExistsKeepExisting=&Giữ tệp hiện tại
FileExistsOverwriteOrKeepAll=&Làm điều này cho các xung đột tiếp theo
ExistingFileNewerSelectAction=Chọn hành động
ExistingFileNewer2=Tệp hiện tại mới hơn tệp mà Setup đang cố gắng cài đặt.
ExistingFileNewerOverwriteExisting=&Ghi đè tệp hiện tại
ExistingFileNewerKeepExisting=&Giữ tệp hiện tại (khuyến nghị)
ExistingFileNewerOverwriteOrKeepAll=&Làm điều này cho các xung đột tiếp theo
ErrorChangingAttr=Đã xảy ra lỗi khi thay đổi thuộc tính của tệp hiện tại:
ErrorCreatingTemp=Đã xảy ra lỗi khi tạo tệp trong thư mục đích:
ErrorReadingSource=Đã xảy ra lỗi khi đọc tệp nguồn:
ErrorCopying=Đã xảy ra lỗi khi sao chép tệp:
ErrorDownloading=Đã xảy ra lỗi khi tải xuống tệp:
ErrorExtracting=Đã xảy ra lỗi khi trích xuất archive:
ErrorReplacingExistingFile=Đã xảy ra lỗi khi thay thế tệp hiện tại:
ErrorRestartReplace=RestartReplace thất bại:
ErrorRenamingTemp=Đã xảy ra lỗi khi đổi tên tệp trong thư mục đích:
ErrorRegisterServer=Không thể đăng ký DLL/OCX: %1
ErrorRegSvr32Failed=RegSvr32 thất bại với mã thoát %1
ErrorRegisterTypeLib=Không thể đăng ký thư viện kiểu: %1

; *** Uninstall display name markings
; used for example as 'My Program (32-bit)'
UninstallDisplayNameMark=%1 (%2)
; used for example as 'My Program (32-bit, All users)'
UninstallDisplayNameMarks=%1 (%2, %3)
UninstallDisplayNameMark32Bit=32-bit
UninstallDisplayNameMark64Bit=64-bit
UninstallDisplayNameMarkAllUsers=Tất cả người dùng
UninstallDisplayNameMarkCurrentUser=Người dùng hiện tại

; *** Post-installation errors
ErrorOpeningReadme=Đã xảy ra lỗi khi mở tệp README.
ErrorRestartingComputer=Setup không thể khởi động lại máy tính. Vui lòng làm thủ công.

; *** Uninstaller messages
UninstallNotFound=Tệp "%1" không tồn tại. Không thể gỡ cài đặt.
UninstallOpenError=Không thể mở tệp "%1". Không thể gỡ cài đặt
UninstallUnsupportedVer=Tệp nhật ký gỡ cài đặt "%1" ở định dạng không được nhận dạng bởi phiên bản trình gỡ cài đặt này. Không thể gỡ cài đặt
UninstallUnknownEntry=Mục không xác định (%1) được tìm thấy trong nhật ký gỡ cài đặt
ConfirmUninstall=Bạn có chắc chắn muốn xóa hoàn toàn %1 và tất cả các thành phần của nó không?
UninstallOnlyOnWin64=Việc gỡ cài đặt này chỉ có thể thực hiện trên Windows 64-bit.
OnlyAdminCanUninstall=Việc gỡ cài đặt này chỉ có thể thực hiện bởi người dùng có quyền quản trị viên.
UninstallStatusLabel=Vui lòng đợi trong khi %1 được xóa khỏi máy tính.
UninstalledAll=%1 đã được xóa thành công khỏi máy tính.
UninstalledMost=Hoàn tất gỡ cài đặt %1.%n%nMột số thành phần không thể được xóa. Chúng có thể được xóa thủ công.
UninstalledAndNeedsRestart=Để hoàn tất việc gỡ cài đặt %1, máy tính phải được khởi động lại.%n%nBạn có muốn khởi động lại không?
UninstallDataCorrupted=Tệp "%1" bị hỏng. Không thể gỡ cài đặt

; *** Uninstallation phase messages
ConfirmDeleteSharedFileTitle=Xóa tệp chia sẻ?
ConfirmDeleteSharedFile2=Hệ thống cho biết tệp chia sẻ sau không còn được bất kỳ chương trình nào sử dụng. Bạn có muốn Gỡ cài đặt xóa tệp chia sẻ này không?%n%nNếu bất kỳ chương trình nào vẫn sử dụng tệp này và nó bị xóa, những chương trình đó có thể không hoạt động đúng. Nếu bạn không chắc chắn, hãy chọn Không. Việc để tệp trên hệ thống sẽ không gây hại.
SharedFileNameLabel=Tên tệp:
SharedFileLocationLabel=Vị trí:
WizardUninstalling=Trạng thái gỡ cài đặt
StatusUninstalling=Đang gỡ cài đặt %1...

; *** Shutdown block reasons
ShutdownBlockReasonInstallingApp=Đang cài đặt %1.
ShutdownBlockReasonUninstallingApp=Đang gỡ cài đặt %1.

; *** Custom Messages
[CustomMessages]

NameAndVersion=%1 phiên bản %2
AdditionalIcons=Biểu tượng tắt bổ sung:
CreateDesktopIcon=Tạo biểu tượng tắt trên &màn hình nền
CreateQuickLaunchIcon=Tạo biểu tượng &Quick Launch
ProgramOnTheWeb=%1 trên Web
UninstallProgram=Gỡ cài đặt %1
LaunchProgram=Khởi động %1
AssocFileExtension=&Liên kết %1 với phần mở rộng tệp %2
AssocingFileExtension=Đang liên kết %1 với phần mở rộng tệp %2...
AutoStartProgramGroupDescription=Khởi động cùng Windows:
AutoStartProgram=Tự động khởi động %1
AddonHostProgramNotFound=%1 không thể được tìm thấy trong thư mục bạn chọn.%n%nBạn có muốn tiếp tục không?
