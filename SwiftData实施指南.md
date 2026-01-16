# SwiftData 建模实施指南

## 当前已完成的工作

### 1. 创建的模型文件 ✅
- `RClick/Model/AppEntity.swift` - 应用实体模型
- `RClick/Model/ActionEntity.swift` - 动作实体模型
- `RClick/Model/NewFileTypeEntity.swift` - 文件类型实体模型
- `RClick/Model/CommonDirEntity.swift` - 常用目录实体模型
- `RClick/Model/DataVersion.swift` - 数据版本控制模型

### 2. 已更新的文件 ✅
- `RClick/Model/ModelContainer.swift` - 已添加所有新模型到容器

## 需要手动操作的步骤

### 步骤1: 在Xcode中添加新文件到Target

由于SwiftData模型需要正确编译链接，必须在Xcode中手动操作：

1. 打开 `RClick.xcodeproj`
2. 在Project Navigator中找到以下新文件（已在文件系统中创建）：
   - `RClick/Model/AppEntity.swift`
   - `RClick/Model/ActionEntity.swift`
   - `RClick/Model/NewFileTypeEntity.swift`
   - `RClick/Model/CommonDirEntity.swift`
   - `RClick/Model/DataVersion.swift`

3. 对于每个文件：
   - 选中文件
   - 在右侧的 "File Inspector" 中
   - 在 "Target Membership" 部分
   - 勾选 `RClick` target
   - 勾选 `FinderSyncExt` target

### 步骤2: 解决编译错误

#### 2.1 AppEntity.swift
需要在文件顶部添加导入：
```swift
import SwiftData
import Foundation
```

删除或注释掉与OpenWithApp的转换方法（第76-92行），因为会导致循环引用。

#### 2.2 ActionEntity.swift
需要删除与RCAction的转换方法。

#### 2.3 NewFileTypeEntity.swift
需要删除与NewFile的转换方法。

#### 2.4 CommonDirEntity.swift
需要删除与CommonDir的转换方法。

### 步骤3: 编译测试

执行以下命令测试编译：
```bash
xcodebuild clean -project RClick.xcodeproj -scheme RClick
xcodebuild build -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

## 下一步工作

完成上述步骤后，继续实施：

1. **实现跨进程同步机制** - 参考 `specs/SwiftData跨进程同步方案.md`
2. **实现Extension的ModelContext初始化**
3. **实现数据迁移工具**
4. **测试和验证**

## 注意事项

⚠️ **关键问题**：
- Extension和Main App是两个独立进程
- 即使使用相同的数据库文件，也没有自动的数据同步
- 必须实现版本控制+通知机制来确保数据一致性

📋 **参考文档**：
- `specs/SwiftData建模方案.md` - 完整的建模方案
- `specs/SwiftData跨进程同步方案.md` - 跨进程同步详细设计
- `架构重构计划.md` - 整体重构计划
