# App Móvil con React Native

Este documento proporciona instrucciones para implementar una versión móvil del Sistema de Gestión de Tareas utilizando React Native, reutilizando componentes del frontend web.

## Requisitos

- Node.js 14+
- NPM o Yarn
- React Native CLI (`npm install -g react-native-cli`)
- XCode (para iOS) o Android Studio (para Android)
- Dispositivo físico o emulador configurado

## Empezando

### 1. Crear un nuevo proyecto de React Native

```bash
npx react-native init TaskManagementApp --template react-native-template-typescript
cd TaskManagementApp
```

### 2. Instalar dependencias

```bash
npm install @react-navigation/native @react-navigation/stack
npm install react-native-gesture-handler react-native-reanimated react-native-screens react-native-safe-area-context @react-native-community/masked-view
npm install @react-native-async-storage/async-storage  # Para almacenamiento local (tokens, etc.)
npm install axios  # Para API calls
npm install react-native-vector-icons  # Para iconos
npm install react-native-chart-kit  # Para gráficos
npm install react-native-dotenv  # Para variables de entorno
```

### 3. Estructura del Proyecto

Organiza el proyecto de la siguiente manera:

```
src/
  ├── api/
  │   └── tasksService.js  # Reutilizar lógica del frontend web
  ├── components/
  │   ├── TaskItem.js      # Versión adaptada del componente web
  │   ├── TaskList.js      # Versión adaptada del componente web
  │   └── TaskForm.js      # Versión adaptada del componente web
  ├── screens/
  │   ├── LoginScreen.js   # Pantalla de inicio de sesión
  │   ├── TasksScreen.js   # Pantalla principal con lista de tareas
  │   └── ChartsScreen.js  # Pantalla de estadísticas
  ├── navigation/
  │   └── AppNavigator.js  # Configuración de navegación
  └── utils/
      └── mockData.js      # Reutilizar datos de prueba
```

### 4. Reutilización de Componentes y Servicios

Al migrar los componentes, ten en cuenta estas diferencias clave:

1. **Estilizado**: 
   - Web: Material-UI con `sx` prop
   - Mobile: StyleSheet de React Native

2. **Navegación**:
   - Web: React Router
   - Mobile: React Navigation

3. **Almacenamiento**:
   - Web: localStorage
   - Mobile: AsyncStorage

### 5. Ejemplo de Conversión de Componentes

A continuación se muestra un ejemplo de cómo adaptar el componente `TaskItem` de web a mobile:

#### Componente Web (TaskItem.js):
```jsx
import React, { useState } from 'react';
import { 
  Card, 
  CardContent, 
  CardActions, 
  Typography, 
  Button,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Box
} from '@mui/material';

const TaskItem = ({ task, onUpdate, onDelete }) => {
  // ... código existente
  
  return (
    <Card 
      sx={{ 
        minWidth: 275, 
        margin: 2,
        boxShadow: 3,
        borderLeft: 6,
        borderColor: status === 'completed' ? 'success.main' : 
                    status === 'in_progress' ? 'warning.main' : 
                    'info.main'
      }}
    >
      {/* ... contenido existente */}
    </Card>
  );
};
```

#### Componente Mobile (TaskItem.js):
```jsx
import React, { useState } from 'react';
import { 
  View, 
  Text, 
  StyleSheet, 
  TouchableOpacity, 
  Platform 
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import Icon from 'react-native-vector-icons/MaterialIcons';

const TaskItem = ({ task, onUpdate, onDelete }) => {
  const [status, setStatus] = useState(task.status || 'todo');
  
  const statusColors = {
    'todo': '#2196f3',        // info
    'in_progress': '#ff9800', // warning
    'completed': '#4caf50'    // success
  };
  
  const statusLabels = {
    'todo': 'Por Hacer',
    'in_progress': 'En Progreso',
    'completed': 'Completada'
  };
  
  const handleStatusChange = (newStatus) => {
    setStatus(newStatus);
    onUpdate(task._id, { ...task, status: newStatus });
  };
  
  return (
    <View style={[
      styles.card, 
      { borderLeftColor: statusColors[status] }
    ]}>
      <View style={styles.content}>
        <Text style={styles.title}>{task.title}</Text>
        <Text style={styles.description}>{task.description}</Text>
        
        <View style={styles.pickerContainer}>
          <Text style={styles.label}>Estado:</Text>
          <Picker
            selectedValue={status}
            style={styles.picker}
            onValueChange={handleStatusChange}
          >
            <Picker.Item label="Por Hacer" value="todo" />
            <Picker.Item label="En Progreso" value="in_progress" />
            <Picker.Item label="Completada" value="completed" />
          </Picker>
        </View>
      </View>
      
      <View style={styles.actions}>
        <TouchableOpacity 
          style={styles.button} 
          onPress={() => onDelete(task._id)}
        >
          <Icon name="delete" size={20} color="#f44336" />
          <Text style={styles.buttonText}>Eliminar</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: 'white',
    borderRadius: 8,
    borderLeftWidth: 6,
    marginVertical: 8,
    marginHorizontal: 16,
    overflow: 'hidden',
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
      },
      android: {
        elevation: 4,
      },
    }),
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  description: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 16,
  },
  pickerContainer: {
    marginTop: 8,
  },
  label: {
    fontSize: 14,
    marginBottom: 4,
  },
  picker: {
    height: 50,
    backgroundColor: '#f5f5f5',
    borderRadius: 4,
  },
  actions: {
    flexDirection: 'row',
    borderTopWidth: 1,
    borderTopColor: '#eeeeee',
    padding: 8,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 8,
  },
  buttonText: {
    marginLeft: 4,
    color: '#f44336',
  }
});

export default TaskItem;
```

### 6. Compartir Lógica de Negocio

Los servicios como `tasksService.js` pueden ser ampliamente reutilizados con modificaciones mínimas

### 7. Rutas y Navegación

```javascript
// AppNavigator.js
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import LoginScreen from '../screens/LoginScreen';
import TasksScreen from '../screens/TasksScreen';
import ChartsScreen from '../screens/ChartsScreen';

const Stack = createStackNavigator();

const AppNavigator = () => {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Login">
        <Stack.Screen 
          name="Login" 
          component={LoginScreen} 
          options={{ headerShown: false }}
        />
        <Stack.Screen 
          name="Tasks" 
          component={TasksScreen} 
          options={{ title: 'Mis Tareas' }}
        />
        <Stack.Screen 
          name="Charts" 
          component={ChartsScreen} 
          options={{ title: 'Estadísticas' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;
```
```

