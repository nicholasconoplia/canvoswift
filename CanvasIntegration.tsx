import React, { useState, useMemo, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
  Linking,
  FlatList,
  Animated,
  AppState,
  useColorScheme,
  Appearance,
  Alert
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { runOnJS } from 'react-native-reanimated';
import { FontAwesomeIcon } from '@fortawesome/react-native-fontawesome';
import { faQuestionCircle } from '@fortawesome/free-solid-svg-icons';
import { colors, spacing, typography, shadows } from '../utils/styles';
import * as animations from '../utils/animations';
import { createFadeAnimation, createSlideAnimation, timings } from '../utils/animations';

interface CanvasAssignment {
  id: string;
  name: string;
  due_at: string | null;
  course_id: string;
  course_name: string;
  points_possible?: number;
  type?: string;
  html_url?: string;
  isSubmitted?: boolean;
  dueDate?: string;
  relativeDue?: string;
  courseCode?: string;
  points?: number;
  courseName?: string;
  targetHeader?: string;
}

interface CanvasEnrollment {
  type: string;
  role: string;
  role_id: number;
  user_id: number;
  enrollment_state: string;
  limit_privileges_to_course_section: boolean;
}

interface CanvasCourse {
  id: string;
  name: string;
  assignments: CanvasAssignment[];
  courseCode?: string;
  workflow_state: string;
  enrollments?: CanvasEnrollment[];
  end_at: string | null;
  start_at: string | null;
  enrollment_term_id: number;
  term?: {
    id: number;
    name: string;
  };
  access_restricted_by_date?: boolean;
  course_code?: string;
}

interface GroupedAssignments {
  [key: string]: {
    courseName: string;
    courseCode: string;
    assignments: CanvasAssignment[];
  };
}

interface CanvasIntegrationProps {
  isDarkMode: boolean;
  onAssignmentSelect: (assignment: CanvasAssignment) => void;
  availableHeaders: string[];
  themeColor: string;
  canvasAssignments?: CanvasAssignment[];
  setCanvasAssignments?: React.Dispatch<React.SetStateAction<CanvasAssignment[]>>;
  hasStoredApiKey?: boolean;
  setHasStoredApiKey?: React.Dispatch<React.SetStateAction<boolean>>;
  currentTier?: 'free' | 'student' | 'lifetime';
  checkHeaderLimit?: () => boolean;
}

interface University {
  name: string;
  url: string;
}

interface AssignmentRowProps {
  assignment: CanvasAssignment;
  isDarkMode: boolean;
  onAssignmentSelect: (assignment: CanvasAssignment) => void;
  availableHeaders: string[];
  themeColor: string;
  currentTier?: 'free' | 'student' | 'lifetime';
  checkHeaderLimit?: () => boolean;
}

const UNIVERSITIES: University[] = [
  { name: 'University of Technology Sydney (UTS)', url: 'https://canvas.uts.edu.au' },
  { name: 'University of Sydney (USyd)', url: 'https://canvas.sydney.edu.au' },
  { name: 'Macquarie University', url: 'https://ilearn.mq.edu.au' },
  { name: 'Western Sydney University', url: 'https://vuws.westernsydney.edu.au' },
  { name: 'Australian Catholic University', url: 'https://canvas.acu.edu.au' },
  { name: 'Custom University', url: '' }
];

// Canvas API URLs will be dynamically set based on university selection
const CANVAS_API_URL = '';

// Define the global window type if not already defined
declare global {
  interface Window {
    TodoAppSubscription?: {
      showSubscriptionModal?: () => void;
      showSubscriptionSuccess?: () => void;
      getCurrentTier?: () => string;
      refreshSubscription?: () => Promise<void>;
    };
  }
}

export function CanvasIntegration({
  isDarkMode,
  onAssignmentSelect,
  availableHeaders,
  themeColor,
  canvasAssignments: externalCanvasAssignments,
  setCanvasAssignments: externalSetCanvasAssignments,
  hasStoredApiKey: externalHasStoredApiKey,
  setHasStoredApiKey: externalSetHasStoredApiKey,
  currentTier = 'free',
  checkHeaderLimit
}: CanvasIntegrationProps) {
  const [showApiKeyModal, setShowApiKeyModal] = useState(false);
  const [showApiGuide, setShowApiGuide] = useState(false);
  const [apiKey, setApiKey] = useState('');
  const [selectedUniversity, setSelectedUniversity] = useState<University>(UNIVERSITIES[0]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [courses, setCourses] = useState<CanvasCourse[]>([]);
  const [selectedCourse, setSelectedCourse] = useState<string>('All Courses');
  const [selectedType, setSelectedType] = useState<string>('All Types');
  const [showCourseDropdown, setShowCourseDropdown] = useState(false);
  const [showTypeDropdown, setShowTypeDropdown] = useState(false);
  const [showUniversityDropdown, setShowUniversityDropdown] = useState(false);
  const [isUniversityDropdownOpen, setIsUniversityDropdownOpen] = useState(false);
  const [customUniversityName, setCustomUniversityName] = useState('');
  const [customUniversityUrl, setCustomUniversityUrl] = useState('');
  const [isCustomUniversity, setIsCustomUniversity] = useState(false);

  // Local state if external state is not provided
  const [localHasStoredApiKey, setLocalHasStoredApiKey] = useState(false);
  const [localCanvasAssignments, setLocalCanvasAssignments] = useState<CanvasAssignment[]>([]);
  
  // Use either the external state or local state
  const hasStoredApiKey = externalHasStoredApiKey !== undefined ? externalHasStoredApiKey : localHasStoredApiKey;
  const setHasStoredApiKey = externalSetHasStoredApiKey || setLocalHasStoredApiKey;
  const canvasAssignments = externalCanvasAssignments || localCanvasAssignments;
  const setCanvasAssignments = externalSetCanvasAssignments || setLocalCanvasAssignments;

  // Animation values - use useMemo instead of useRef to avoid NOBRIDGE warning
  const fadeAnim = React.useMemo(() => new Animated.Value(0), []);
  const slideAnim = React.useMemo(() => new Animated.Value(100), []);

  const dynamicStyles = useMemo(() => StyleSheet.create({
    container: {
      marginTop: 16,
      marginBottom: 40,
      backgroundColor: isDarkMode ? '#1a1a1a' : '#fff',
      borderRadius: 20,
      overflow: 'hidden',
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.15,
      shadowRadius: 16,
      elevation: 8,
      minHeight: 150,
      flex: 1,
    },
    
    // Update the canvasContentWrapper style to respect dark mode 
    canvasContentWrapper: {
      flex: 1, 
      padding: 16, 
      paddingBottom: 10, // Ensure minimal bottom padding here
      backgroundColor: isDarkMode ? '#1a1a1a' : '#fff',
      borderBottomLeftRadius: 20,
      borderBottomRightRadius: 20,
    },
    
    // Update the headerContainer to use themeColor
    headerContainer: {
      flexDirection: 'row',
      justifyContent: 'center',
      alignItems: 'center',
      padding: 12,
      backgroundColor: themeColor,
      borderTopLeftRadius: 20,
      borderTopRightRadius: 20,
      shadowColor: themeColor,
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.1,
      shadowRadius: 2,
    },
    
    // Update the canvasActions style to use proper dark mode
    canvasActions: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      gap: 12,
      padding: 16,
      backgroundColor: isDarkMode ? '#2a2a2a' : '#f8f8f8',
      borderRadius: 16,
      marginBottom: 16,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.1,
      shadowRadius: 2,
      elevation: 2,
    },
    
    // Update the loadButton style to use themeColor
    loadButton: {
      flex: 1,
      backgroundColor: themeColor,
      paddingVertical: 12,
      paddingHorizontal: 16,
      borderRadius: 16,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 2,
      alignItems: 'center', 
      justifyContent: 'center',
    },
    
    loadButtonText: {
      color: '#fff',
      fontWeight: '600',
      fontSize: 15,
      textAlign: 'center',
    },
    
    // Update the filtersContainer to respect dark mode
    filtersContainer: {
      flexDirection: 'row',
      gap: 12,
      padding: 16,
      backgroundColor: isDarkMode ? '#2a2a2a' : '#f8f8f8',
      borderRadius: 16,
      marginBottom: 16,
    },
    
    // Ensure filterButton is defined only ONCE
    filterButton: {
      flex: 1,
      backgroundColor: isDarkMode ? '#3a3a3c' : '#ffffff',
      padding: 12,
      borderRadius: 16,
      alignItems: 'center',
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.1,
      shadowRadius: 2,
      elevation: 1,
    },
    darkFilterButton: {
      backgroundColor: '#2c2c2e', // Specific dark mode style for filterButton
    },
    headerTitle: {
      color: '#fff',
      fontSize: 16,
      fontWeight: '500',
      letterSpacing: -0.2,
    },
    darkLoadButton: {
      backgroundColor: '#ff453a',
    },
    dropdownOverlay: {
      flex: 1,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      justifyContent: 'center',
      alignItems: 'center',
    },
    dropdownContent: {
      backgroundColor: '#fff',
      borderRadius: 12,
      padding: 8,
      width: '80%',
      maxWidth: 300,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.15,
      shadowRadius: 12,
    },
    darkDropdownContent: {
      backgroundColor: '#2a2a2a',
    },
    dropdownTitle: {
      fontSize: 18,
      fontWeight: '600',
      textAlign: 'center',
      padding: 10,
      borderBottomWidth: 1,
      borderBottomColor: '#eee',
      marginBottom: 5,
    },
    dropdownItem: {
      padding: 16,
      borderBottomWidth: 1,
      borderBottomColor: '#eee',
    },
    dropdownText: {
      fontSize: 16,
      color: '#333',
      textAlign: 'center',
    },
    selectedDropdownText: {
      fontWeight: 'bold',
      color: themeColor,
    },
    removeKeyButton: {
      flex: 1,
      backgroundColor: '#3a3a3c',
      padding: 14,
      borderRadius: 12,
      alignItems: 'center',
    },
    darkRemoveKeyButton: {
      backgroundColor: '#2c2c2e',
    },
    removeKeyButtonText: {
      color: '#fff',
      fontSize: 15,
      fontWeight: '600',
      letterSpacing: 0.3,
    },
    courseHeader: {
      backgroundColor: themeColor,
      padding: 16,
      borderRadius: 16,
      marginBottom: 16,
      marginTop: 20,
      shadowColor: themeColor,
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.15,
      shadowRadius: 8,
    },
    courseHeaderText: {
      color: '#fff',
      fontSize: 17,
      fontWeight: '600',
      letterSpacing: -0.3,
    },
    filterText: {
      fontSize: 15,
      color: '#333',
      fontWeight: '500',
      textAlign: 'center',
    },
    darkFilterText: {
      color: '#fff',
    },
    apiGuideStepNumber: {
      width: 28,
      height: 28,
      borderRadius: 14,
      backgroundColor: themeColor,
      color: '#fff',
      textAlign: 'center',
      lineHeight: 28,
      fontSize: 16,
      fontWeight: 'bold',
      marginRight: 16,
    },
    apiGuideLinkButton: {
      backgroundColor: themeColor,
      paddingHorizontal: 16,
      paddingVertical: 8,
      borderRadius: 8,
      alignSelf: 'flex-start',
    },
    apiGuideNote: {
      backgroundColor: isDarkMode ? `${themeColor}20` : `${themeColor}20`, // 20 = 5% opacity (lighter in both modes)
      padding: 16,
      borderRadius: 8,
      marginTop: 8,
      marginBottom: 16,
    },
    apiGuideNoteText: {
      fontSize: 14,
      color: isDarkMode ? '#ffffff' : '#000000',
    },
    headerButton: {
      color: themeColor,
      fontSize: 16,
      padding: 8,
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif',
    },
    headerSelector: {
      marginBottom: 16,
    },
    modeSelector: {
      padding: 16,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: 12,
      marginBottom: 12,
      backgroundColor: colors.background,
    },
    selectedModeSelector: {
      borderColor: colors.primary,
      backgroundColor: colors.backgroundAlt,
    },
    headersList: {
      maxHeight: 200,
      marginBottom: 12,
      borderRadius: 12,
      overflow: 'hidden',
    },
    headerOption: {
      padding: 16,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: 12,
      marginBottom: 8,
      backgroundColor: colors.background,
    },
    selectedHeaderOption: {
      borderColor: colors.primary,
      backgroundColor: colors.backgroundAlt,
    },
    darkHeaderSelector: {
      borderColor: colors.border,
      backgroundColor: colors.backgroundDark,
    },
    headerOptionText: {
      fontSize: 16,
      color: colors.text,
      fontWeight: '500' as const,
    },
    selectedHeaderOptionText: {
      color: colors.primary,
      fontWeight: '600' as const,
    },
    headerInput: {
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: 12,
      padding: 16,
      marginBottom: 16,
      fontSize: 16,
      color: colors.text,
      backgroundColor: colors.background,
    },
    darkHeaderInput: {
      borderColor: colors.border,
      backgroundColor: colors.backgroundDark,
      color: colors.textDark,
    },
    addButton: {
      backgroundColor: themeColor,
      flex: 1,
      padding: 10,
      borderRadius: 8,
      alignItems: 'center',
    },
    courseFilterButton: {
      flex: 1,
      backgroundColor: '#fff',
      padding: 14,
      borderRadius: 12,
      borderWidth: 1,
      borderColor: '#eee',
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.05,
      shadowRadius: 4,
    },
    darkCourseFilterButton: {
      backgroundColor: '#2a2a2a',
      borderColor: '#333',
    },
    darkText: {
      color: '#fff',
    },
    loadingContainer: {
      padding: 20,
      alignItems: 'center',
      justifyContent: 'center',
    },
    loadingText: {
      marginTop: 10,
      fontSize: 16,
      color: '#333',
    },
    errorText: {
      color: '#ff3b30',
      fontSize: 15,
      textAlign: 'center',
      margin: 20,
    },
    assignmentsContainer: {
      flex: 1, // Allow ScrollView to expand
      // Remove maxHeight: 450 to allow filling space
      // Remove paddingHorizontal: 16, let canvasContentWrapper handle padding
    },
    modalOverlay: {
      flex: 1,
      backgroundColor: 'rgba(0, 0, 0, 0.6)',
      justifyContent: 'center',
      alignItems: 'center',
    },
    modalContent: {
      backgroundColor: '#fff',
      borderRadius: 20,
      padding: 24,
      width: '90%',
      maxWidth: 420,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.15,
      shadowRadius: 16,
    },
    darkModalContent: {
      backgroundColor: '#1a1a1a',
    },
    modalHeader: {
      flexDirection: 'row',
      alignItems: 'flex-start',  // Changed from 'center' to 'flex-start'
      marginBottom: 20,
      paddingRight: 40,  // Added padding to make room for the close button
    },
    modalTitle: {
      fontSize: 24,
      fontWeight: '700' as const,
      color: colors.text,
      letterSpacing: -0.5,
      flexShrink: 1,  // Changed from flex: 1 to flexShrink: 1 to allow wrapping
    },
    closeButtonContainer: {
      width: 28,
      height: 28,
      borderRadius: 14,
      backgroundColor: isDarkMode ? `${themeColor}50` : `${themeColor}20`,
      justifyContent: 'center',
      alignItems: 'center',
      display: 'flex',
      position: 'absolute',
      top: 4,  // Adjusted from 0 to 4 for better vertical spacing
      right: 4,  // Adjusted from 0 to 4 for better horizontal spacing
      zIndex: 10,
    },
    closeButtonText: {
      fontSize: 16,
      color: isDarkMode ? '#ffffff' : '#000000',
      fontWeight: '600',
      textAlign: 'center',
      lineHeight: 16,
    },
    modalDescription: {
      fontSize: 15,
      color: '#666',
      marginBottom: 20,
      lineHeight: 22,
    },
    universitySelector: {
      borderWidth: 1,
      borderColor: themeColor,
      borderRadius: 12,
      padding: 14,
      marginBottom: 16,
      backgroundColor: isDarkMode ? '#333' : '#f5f5f5',
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 3,
      elevation: 2,
    },
    darkUniversitySelector: {
      borderColor: themeColor,
      backgroundColor: '#2a2a2a',
    },
    universitySelectorText: {
      fontSize: 16,
      color: isDarkMode ? '#fff' : '#333',
      flex: 1,
      fontWeight: '500',
    },
    dropdownIndicator: {
      marginLeft: 8,
    },
    dropdownArrow: {
      fontSize: 12,
      color: '#666',
      fontWeight: '600',
    },
    universityDropdownContainer: {
      position: 'relative',
      marginBottom: 16,
      zIndex: 100,
    },
    universityDropdownList: {
      position: 'absolute',
      top: '100%', 
      left: 0,
      right: 0,
      backgroundColor: isDarkMode ? '#1a1a1a' : '#fff',
      borderRadius: 12,
      borderWidth: 1,
      borderColor: themeColor,
      marginTop: 4,
      maxHeight: 200,
      zIndex: 1000,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.15,
      shadowRadius: 8,
      elevation: 5,
    },
    universityDropdownItem: {
      padding: 14,
      borderBottomWidth: 1,
      borderBottomColor: isDarkMode ? '#333' : '#eee',
    },
    universityDropdownItemText: {
      fontSize: 15,
      color: isDarkMode ? '#fff' : '#333',
      fontWeight: '400',
    },
    selectedUniversityText: {
      fontWeight: '600',
      color: themeColor,
    },
    apiKeyContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: 12,
      marginBottom: 20,
    },
    input: {
      flex: 1,
      borderWidth: 1,
      borderColor: '#e5e5e5',
      borderRadius: 12,
      padding: 14,
      fontSize: 16,
      color: '#333',
      backgroundColor: '#f8f8f8',
    },
    darkInput: {
      borderColor: '#333',
      backgroundColor: '#2a2a2a',
      color: '#fff',
    },
    helpButton: {
      padding: 8,
      backgroundColor: isDarkMode ? '#2a2a2a' : '#f8f8f8',
      borderRadius: 10,
    },
    modalButtons: {
      flexDirection: 'row',
      justifyContent: 'flex-end',
      gap: 12,
      marginTop: 8,
    },
    modalButton: {
      paddingHorizontal: 20,
      paddingVertical: 12,
      borderRadius: 12,
      minWidth: 120,
      alignItems: 'center',
      justifyContent: 'center',
    },
    cancelButton: {
      backgroundColor: isDarkMode ? 'rgba(255, 255, 255, 0.3)' : 'rgba(0, 0, 0, 0.3)',
    },
    cancelButtonText: {
      color: isDarkMode ? '#ffffff' : '#000000',
      fontSize: 16,
      fontWeight: '600' as const,
      letterSpacing: 0.3,
    },
    saveButton: {
      backgroundColor: themeColor,
      shadowColor: '#000000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.1,
      shadowRadius: 2,
      elevation: 2,
    },
    buttonText: {
      color: '#ffffff',
      fontSize: 16,
      fontWeight: '600' as const,
      letterSpacing: 0.3,
    },
    selectedDropdownItem: {
      backgroundColor: isDarkMode ? `${themeColor}30` : `${themeColor}20`,
      borderColor: themeColor,
      borderWidth: 1,
    },
    apiGuideModal: {
      maxHeight: '80%',
    },
    apiGuideContent: {
      paddingTop: 16,
    },
    apiGuideStep: {
      flexDirection: 'row',
      marginBottom: 24,
      alignItems: 'flex-start',
    },
    apiGuideStepContent: {
      flex: 1,
    },
    apiGuideStepTitle: {
      fontSize: 18,
      fontWeight: 'bold',
      color: '#333',
      marginBottom: 8,
    },
    apiGuideStepDescription: {
      fontSize: 16,
      color: '#666',
      lineHeight: 22,
      marginBottom: 12,
    },
    apiGuideLinkButtonText: {
      color: '#fff',
      fontSize: 14,
      fontWeight: 'bold',
    },
    disabledButton: {
      backgroundColor: colors.backgroundAlt,
      opacity: 0.7,
    },
    assignmentRow: {
      backgroundColor: '#fff',
      borderRadius: 16,
      marginBottom: 16,
      overflow: 'hidden',
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 2,
    },
    darkAssignmentRow: {
      backgroundColor: '#2a2a2a',
    },
    assignmentContent: {
      padding: 16,
    },
    assignmentName: {
      fontSize: 16,
      fontWeight: '600',
      color: '#333',
      marginBottom: 8,
    },
    assignmentMeta: {
      gap: 12,
    },
    badgeContainer: {
      flexDirection: 'row',
      gap: 8,
      marginBottom: 8,
    },
    badge: {
      paddingHorizontal: 8,
      paddingVertical: 4,
      borderRadius: 8,
    },
    typeBadge: {
      backgroundColor: `${themeColor}80`, // 80 = 50% opacity in hex
    },
    typeBadgeText: {
      color: '#ffffff',
      fontSize: 12,
      fontWeight: '600',
    },
    submittedBadge: {
      backgroundColor: '#e8f5e9',
    },
    notSubmittedBadge: {
      paddingHorizontal: 6,
      paddingVertical: 3,
      borderRadius: 8,
      marginLeft: 6,
    },
    badgeText: {
      fontSize: 12,
      fontWeight: '600',
      color: '#333',
    },
    dueDateContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: 8,
      marginBottom: 12,
    },
    dueDate: {
      fontSize: 14,
      color: '#666',
    },
    overdueBubble: {
      borderRadius: 8,
    },
    dueSoonBubble: {
      backgroundColor: `${themeColor}80`, // 80 = 50% opacity in hex
    },
    daysLeftBubble: {
      backgroundColor: isDarkMode ? '#444444' : '#e0e0e0',
      paddingHorizontal: 10,
      paddingVertical: 5,
    },
    actionButtons: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      gap: 10,
      marginTop: 10,
    },
    viewButton: {
      paddingHorizontal: 14,
      paddingVertical: 10,
      borderRadius: 8,
      backgroundColor: isDarkMode ? `${themeColor}60` : `${themeColor}80`,
      flex: 1,
      alignItems: 'center',
    },
    viewButtonText: {
      fontSize: 12,
      fontWeight: 'bold',
      color: '#ffffff',
    },
    actionAddButton: {
      paddingHorizontal: 14,
      paddingVertical: 10,
      borderRadius: 8,
      backgroundColor: themeColor,
      flex: 1,
      alignItems: 'center',
    },
    addButtonText: {
      color: '#fff',
      fontSize: 12,
      fontWeight: '600',
    },
  }), [isDarkMode, themeColor]);

  // Define the types array
  const types = useMemo(() => {
    return ['All Types', 'Quiz', 'Assignment'];
  }, []);

  useEffect(() => {
    checkStoredApiKey();
    checkStoredCanvasUrl();
    
    // If we have canvas assignments from props, set them to courses
    if (canvasAssignments && canvasAssignments.length > 0 && courses.length === 0) {
      console.log('[DEBUG] Using existing canvas assignments to populate courses:', canvasAssignments.length);
      
      // Group assignments by course
      const groupedByCourse: Record<string, CanvasAssignment[]> = {};
      canvasAssignments.forEach(assignment => {
        const courseName = assignment.course_name || 'Unknown Course';
        if (!groupedByCourse[courseName]) {
          groupedByCourse[courseName] = [];
        }
        groupedByCourse[courseName].push(assignment);
      });
      
      // Convert to courses format with all required properties for CanvasCourse
      const formattedCourses: CanvasCourse[] = Object.entries(groupedByCourse).map(([courseName, assignments]) => ({
        id: courseName.replace(/\s+/g, '_').toLowerCase(),
        name: courseName,
        assignments,
        courseCode: courseName,
        workflow_state: 'available',
        end_at: null,
        start_at: null,
        enrollment_term_id: 0,
        enrollments: [{
          type: 'student',
          role: 'StudentEnrollment',
          role_id: 0,
          user_id: 0,
          enrollment_state: 'active',
          limit_privileges_to_course_section: false
        }]
      }));
      
      setCourses(formattedCourses);
    }
    
    // Always reset animation values and animate when component mounts or tab changes
    fadeAnim.setValue(0);
    slideAnim.setValue(100);
    
    // Animate component mount with a slight delay to ensure proper rendering
    setTimeout(() => {
      Animated.parallel([
        createFadeAnimation(fadeAnim, 1, animations.timings.normal),
        createSlideAnimation(slideAnim, 0, animations.timings.normal)
      ]).start();
      console.log('[DEBUG] Started Canvas animation');
    }, 100);
  }, [canvasAssignments]);

  const checkStoredApiKey = async () => {
    try {
      const savedApiKey = await AsyncStorage.getItem('canvasApiKey');
      setHasStoredApiKey(!!savedApiKey);
    } catch (error) {
      console.error('Error checking stored API key:', error);
    }
  };

  const checkStoredCanvasUrl = async () => {
    try {
      const savedUrl = await AsyncStorage.getItem('canvasUrl');
      if (savedUrl) {
        // Check if this is a custom university
        const savedCustomName = await AsyncStorage.getItem('customUniversityName');
        const savedCustomUrl = await AsyncStorage.getItem('customUniversityUrl');
        
        if (savedCustomName && savedCustomUrl) {
          // We have a custom university
          const customUniversity: University = {
            name: savedCustomName,
            url: savedCustomUrl
          };
          setSelectedUniversity(customUniversity);
          setCustomUniversityName(savedCustomName);
          setCustomUniversityUrl(savedCustomUrl);
          setIsCustomUniversity(true);
        } else {
          // Try to find a matching predefined university
          const university = UNIVERSITIES.find(u => savedUrl.startsWith(u.url)) || UNIVERSITIES[0];
          setSelectedUniversity(university);
          setIsCustomUniversity(false);
        }
      }
    } catch (error) {
      console.error('Error checking stored Canvas URL:', error);
    }
  };

  const allAssignments = useMemo(() => {
    // If we have externally provided assignments and courses is empty, use those
    if (canvasAssignments && canvasAssignments.length > 0 && courses.length === 0) {
      console.log('Using cached canvas assignments:', canvasAssignments.length);
      return canvasAssignments;
    }
    
    // Otherwise, use the assignments from courses
    let assignments: CanvasAssignment[] = [];
    courses.forEach(course => {
      console.log(`Adding assignments from course: ${course.name}`, course.assignments);
      assignments = [...assignments, ...course.assignments];
    });
    console.log('All assignments before sorting:', assignments);
    // Sort all assignments by due date
    return assignments.sort((a, b) => {
      if (!a.dueDate || a.dueDate === 'No due date') return 1;
      if (!b.dueDate || b.dueDate === 'No due date') return -1;
      const dateA = new Date(a.dueDate.replace(' at ', ' '));
      const dateB = new Date(b.dueDate.replace(' at ', ' '));
      return dateA.getTime() - dateB.getTime();
    });
  }, [courses, canvasAssignments]);

  const filteredAssignments = useMemo(() => {
    console.log('Starting to filter assignments. Total count:', allAssignments.length);
    const assignments = allAssignments.filter(assignment => {
      console.log(`\nFiltering assignment: "${assignment.name}"`, {
        courseName: assignment.course_name,
        type: assignment.type,
        dueDate: assignment.dueDate
      });

      const courseMatch = selectedCourse === 'All Courses' || assignment.course_name === selectedCourse;
      if (!courseMatch) {
        console.log('Filtered out: Course doesn\'t match', {
          selectedCourse,
          assignmentCourse: assignment.course_name
        });
      }
      
      const typeMatch = selectedType === 'All Types' || 
        (selectedType === 'Quiz' && assignment.type?.toLowerCase().includes('quiz')) ||
        (selectedType === 'Assignment' && !assignment.type?.toLowerCase().includes('quiz'));
      
      if (!typeMatch) {
        console.log('Filtered out: Type doesn\'t match', {
          selectedType,
          assignmentType: assignment.type
        });
      }

      const keep = courseMatch && typeMatch;
      console.log('Assignment will be', keep ? 'kept' : 'filtered out');
      return keep;
    });

    // Sort assignments by course first, then by due date within each course
    return assignments.sort((a, b) => {
      // First sort by course if in All Courses view
      if (selectedCourse === 'All Courses') {
        const courseCompare = (a.course_name || '').localeCompare(b.course_name || '');
        if (courseCompare !== 0) return courseCompare;
      }

      // Then sort by due date
      if (!a.dueDate || a.dueDate === 'No due date') return 1;
      if (!b.dueDate || b.dueDate === 'No due date') return -1;
      const dateA = new Date(a.dueDate.replace(' at ', ' '));
      const dateB = new Date(b.dueDate.replace(' at ', ' '));
      return dateA.getTime() - dateB.getTime();
    });
  }, [allAssignments, selectedCourse, selectedType]);

  const uniqueTypes = useMemo(() => {
    // Always return these three options
    return ['All Types', 'Quiz', 'Assignment'];
  }, []);

  const handleSaveApiKey = async () => {
    if (!apiKey.trim()) {
      setError('Please enter your Canvas API key');
      return;
    }

    // Validate custom university inputs if custom university is selected
    if (isCustomUniversity) {
      if (!customUniversityName.trim()) {
        setError('Please enter your university name');
        return;
      }
      
      if (!customUniversityUrl.trim()) {
        setError('Please enter your Canvas URL');
        return;
      }
      
      if (!customUniversityUrl.startsWith('http://') && !customUniversityUrl.startsWith('https://')) {
        setError('Canvas URL must start with http:// or https://');
        return;
      }
      
      // Create a custom university object
      const customUniversity: University = {
        name: customUniversityName.trim(),
        url: customUniversityUrl.trim()
      };
      
      // Update the selected university with the custom values
      setSelectedUniversity(customUniversity);
    }
    
    try {
      // Determine which URL to use - either the selected university or custom
      let baseUrl = isCustomUniversity ? customUniversityUrl.trim() : selectedUniversity.url.trim();
      
      // Normalize the Canvas URL
      baseUrl = baseUrl.toLowerCase();
      
      // Remove trailing slashes
      baseUrl = baseUrl.replace(/\/+$/, '');
      
      // Ensure https protocol
      if (!baseUrl.startsWith('http')) {
        baseUrl = 'https://' + baseUrl;
      }
      
      // Add API version path if not present
      const normalizedUrl = baseUrl.includes('/api/v1') ? baseUrl : baseUrl + '/api/v1';

      console.log('Normalized Canvas URL:', normalizedUrl);

      // Test the API key with a simple request before saving
      const testResponse = await fetch(`${normalizedUrl}/users/self`, {
        headers: {
          'Authorization': `Bearer ${apiKey.trim()}`,
          'Accept': 'application/json'
        }
      });

      if (!testResponse.ok) {
        if (testResponse.status === 401) {
          throw new Error('Invalid API key. Please make sure you:\n1. Generated a new API key\n2. Copied the entire key\n3. Are logged into Canvas in your browser');
        }
        throw new Error(`Failed to validate API key (Status: ${testResponse.status})`);
      }

      // If we get here, the API key is valid
      await AsyncStorage.setItem('canvasApiKey', apiKey.trim());
      await AsyncStorage.setItem('canvasUrl', normalizedUrl);
      
      // Also save the custom university information if applicable
      if (isCustomUniversity) {
        await AsyncStorage.setItem('customUniversityName', customUniversityName.trim());
        await AsyncStorage.setItem('customUniversityUrl', customUniversityUrl.trim());
      }
      
      // Check if this is the first time the user connected Canvas
      const hasShownSubscription = await AsyncStorage.getItem('hasShownSubscriptionAfterCanvas');
      
      // Mark that Canvas is connected - needed for subscription checks
      await AsyncStorage.setItem('canvasConnected', 'true');
      
      // Close the API modal first
      setShowApiKeyModal(false);
      setHasStoredApiKey(true);
      
      // Fetch assignments
      fetchAssignments();
      
      // Show subscription modal after a small delay (to allow the API modal to close)
      setTimeout(() => {
        // Simplified approach using global function
        if (!hasShownSubscription) {
          // Mark as shown so we don't show it again
          AsyncStorage.setItem('hasShownSubscriptionAfterCanvas', 'true');
          
          // Access the global function if available safely
          if (typeof window !== 'undefined' &&
              window.TodoAppSubscription &&
              typeof window.TodoAppSubscription.showSubscriptionSuccess === 'function') { // Check if function exists
            window.TodoAppSubscription.showSubscriptionSuccess();
          } else {
            // Fallback: set flag for next app start
            console.warn('[CanvasIntegration] showSubscriptionSuccess function not found on window.TodoAppSubscription');
            AsyncStorage.setItem('showSubscriptionOnNextStart', 'true');
          }
        }
      }, 500);
    } catch (error) {
      console.error('Error saving API key:', error);
      setError(error instanceof Error ? error.message : 'Failed to save API key');
    }
  };

  const handleRemoveApiKey = async () => {
    try {
      await AsyncStorage.removeItem('canvasApiKey');
      await AsyncStorage.removeItem('canvasUrl');
      await AsyncStorage.removeItem('customUniversityName');
      await AsyncStorage.removeItem('customUniversityUrl');
      
      setHasStoredApiKey(false);
      setCourses([]);
      setApiKey('');
      setSelectedUniversity(UNIVERSITIES[0]);
      setCustomUniversityName('');
      setCustomUniversityUrl('');
      setIsCustomUniversity(false);
      setError(null);
    } catch (error) {
      console.error('Error removing API key:', error);
    }
  };

  const fetchAssignments = async () => {
    // Always fetch fresh assignments regardless of cache
    setLoading(true);
    setError(null);
    console.log('[DEBUG] Starting Canvas assignment fetch...');
    
    try {
      const savedApiKey = await AsyncStorage.getItem('canvasApiKey');
      const savedUrl = await AsyncStorage.getItem('canvasUrl');
      
      if (!savedApiKey || !savedUrl) {
        setShowApiKeyModal(true);
        setLoading(false);
        return;
      }

      // Fetch only active courses with enrollments
      console.log('Fetching courses from:', savedUrl);
      let courses;
      
      // Basic validation for API key
      if (!savedApiKey || savedApiKey.trim().length === 0) {
        throw new Error('Please enter your Canvas API key');
      }

      const coursesResponse = await fetch(
        `${savedUrl}/courses?` + new URLSearchParams({
          'enrollment_state': 'active',
          'enrollment_type': 'student',
          'state[]': 'available',
          'include[]': ['term', 'total_students', 'concluded'].join(','),
          'per_page': '100'
        }),
        {
        headers: {
          'Authorization': `Bearer ${savedApiKey}`,
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
        },
          method: 'GET'
        }
      );

      console.log('Courses response status:', coursesResponse.status);
      console.log('Response headers:', Object.fromEntries(coursesResponse.headers.entries()));
      
      // Handle different response statuses
      if (!coursesResponse.ok) {
        const responseText = await coursesResponse.text();
        console.log('Raw courses response:', responseText);
        
        let errorMessage = 'Failed to fetch courses';
        try {
          const errorData = JSON.parse(responseText);
          if (errorData.errors && errorData.errors[0]) {
            errorMessage = errorData.errors[0].message;
          }
        } catch (e) {
          console.error('Failed to parse error response:', e);
        }

        if (coursesResponse.status === 401) {
          throw new Error('Invalid API key. Please make sure you:\n1. Generated a new API key\n2. Copied the entire key');
        } else if (coursesResponse.status === 404) {
          throw new Error('Canvas API endpoint not found. Please check your university\'s Canvas URL.');
        } else if (coursesResponse.status >= 500) {
          // For 500 errors, try a different endpoint
          console.log('Got 500 error, trying alternative endpoint...');
          
          const retryResponse = await fetch(
            `${savedUrl}/users/self/courses?` + new URLSearchParams({
              'enrollment_state': 'active',
              'enrollment_type': 'student',
              'include[]': ['term', 'total_students'].join(','),
              'per_page': '100'
            }),
            {
              headers: {
                'Authorization': `Bearer ${savedApiKey}`,
                'Accept': 'application/json',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
              }
            }
          );

          if (!retryResponse.ok) {
            throw new Error(`Failed to fetch courses (Status: ${retryResponse.status}). Please try:\n1. Generating a new API key\n2. Checking if the Canvas URL is correct`);
          }

          const retryText = await retryResponse.text();
          console.log('Retry response:', retryText);
          try {
            courses = JSON.parse(retryText);
          } catch (e) {
            console.error('Failed to parse retry response:', e);
            throw new Error('Invalid response format from Canvas API');
          }
        } else {
          throw new Error(`${errorMessage} (Status: ${coursesResponse.status})`);
        }
      } else {
        const responseText = await coursesResponse.text();
        console.log('Raw courses response:', responseText);
        try {
          courses = JSON.parse(responseText);
        } catch (error) {
          console.error('Failed to parse courses response:', error);
          throw new Error('Invalid response from Canvas API');
        }
      }

      if (!courses || courses.length === 0) {
        throw new Error('No current courses found. Please check if you have any active course enrollments.');
      }
      
      // Filter courses to only include active ones
      const now = new Date();
      const currentCourses = courses.filter((course: CanvasCourse) => {
        // Log course details for debugging
        console.log('Checking course:', course.name, {
          enrollmentState: course.enrollments?.[0]?.enrollment_state,
          workflowState: course.workflow_state,
          accessRestrictedByDate: course.access_restricted_by_date,
          startAt: course.start_at,
          endAt: course.end_at,
          termId: course.enrollment_term_id,
          termName: course.term?.name
        });
        
        // Skip non-academic courses
        if (course.name.includes('Consent Matters') || 
            course.name === 'FEIT OPELA') {
          console.log('Skipping non-current course:', course.name);
          return false;
        }

        // Match the filtering logic for current courses
        return (
          course.workflow_state === 'available' &&
          course.enrollments?.some((e: CanvasEnrollment) => e.enrollment_state === 'active')
        );
      });

      if (currentCourses.length === 0) {
        throw new Error('No current courses found. Please check if you have any active course enrollments.');
      }

      console.log('Current courses:', currentCourses);

      // Fetch assignments for each course
      console.log('Starting to fetch assignments for each course...');
      const assignmentPromises = currentCourses.map(async (course: any) => {
        try {
          console.log(`Fetching assignments for course ${course.id} (${course.name})...`);
          // First fetch assignments with all necessary parameters
          const assignmentsResponse = await fetch(
            `${savedUrl}/courses/${course.id}/assignments?` + new URLSearchParams({
              'include[]': ['submission', 'due_dates', 'all_dates', 'overrides', 'observed_users'].join(','),
              'bucket': 'future',
              'order_by': 'due_at',
              'per_page': '100',
              'needs_grading_count_by_section': 'false'
            }),
            {
              headers: {
                'Authorization': `Bearer ${savedApiKey}`,
                'Accept': 'application/json',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
              }
            }
          );

          console.log(`Assignments response status for course ${course.id}:`, assignmentsResponse.status);
          const assignmentsText = await assignmentsResponse.text();
          console.log(`Raw assignments response for course ${course.id}:`, assignmentsText);

          if (!assignmentsResponse.ok) {
            console.warn(`Failed to fetch assignments for course ${course.id}:`, assignmentsText);
            return [];
          }

          const assignments = JSON.parse(assignmentsText);
          console.log(`Parsed assignments for course ${course.name}:`, assignments);
          const now = new Date();

          // For each assignment, fetch its submission details
          const assignmentsWithSubmissions = await Promise.all(assignments
            .filter((assignment: any) => {
              // Only include published assignments with due dates
              return assignment.published && assignment.due_at;
            })
            .map(async (assignment: any) => {
              // Log the raw assignment data to debug due dates
              console.log('Raw assignment data:', {
                name: assignment.name,
                due_at: assignment.due_at,
                lock_at: assignment.lock_at,
                all_dates: assignment.all_dates,
                raw_date_string: assignment.due_at ? new Date(assignment.due_at).toISOString() : null,
                parsed_date: assignment.due_at ? new Date(assignment.due_at) : null
              });

              // Fetch submission details for this assignment
              const submissionResponse = await fetch(
                `${savedUrl}/courses/${course.id}/assignments/${assignment.id}/submissions/self?include[]=submission_history`,
                {
                  headers: {
                    'Authorization': `Bearer ${savedApiKey}`
                  }
                }
              );

              let submissionData = null;
              if (submissionResponse.ok) {
                submissionData = await submissionResponse.json();
              }

              // Get the due date from the assignment
              let dueDate = null;
              let formattedDate = 'No due date';
              let originalDueAt = null;
              
              // First try the due_at field
              if (assignment.due_at) {
                dueDate = new Date(assignment.due_at);
                originalDueAt = assignment.due_at;
                console.log('Processing due date for:', assignment.name, {
                  original_due_at: assignment.due_at,
                  parsed_date: dueDate,
                  iso_string: dueDate.toISOString(),
                  local_string: dueDate.toString(),
                  utc_string: dueDate.toUTCString(),
                  timezone_offset: dueDate.getTimezoneOffset()
                });

                // Format the date if we found one
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                formattedDate = `${dueDate.getDate()} ${months[dueDate.getMonth()]} at ${String(dueDate.getHours()).padStart(2, '0')}:${String(dueDate.getMinutes()).padStart(2, '0')}`;
                console.log('Formatted date:', {
                  assignment: assignment.name,
                  original_due_at: originalDueAt,
                  formatted_date: formattedDate,
                  due_date_obj: dueDate,
                  iso_string: dueDate.toISOString()
                });
              }
              // If no due_at, try lock_at
              else if (assignment.lock_at) {
                dueDate = new Date(assignment.lock_at);
                originalDueAt = assignment.lock_at;
                console.log('Using lock_at date for:', assignment.name, {
                  original_lock_at: assignment.lock_at,
                  parsed_date: dueDate
                });

                // Format lock_at date
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                formattedDate = `${dueDate.getDate()} ${months[dueDate.getMonth()]} at ${String(dueDate.getHours()).padStart(2, '0')}:${String(dueDate.getMinutes()).padStart(2, '0')}`;
              }

              // Simplified submission status check
              const isSubmitted = Boolean(
                submissionData && (
                  submissionData.workflow_state === 'submitted' ||
                  submissionData.workflow_state === 'graded' ||
                  (submissionData.submitted_at && submissionData.attempt > 0)
                )
              );

              const processedAssignment = {
                id: assignment.id,
                name: assignment.name,
                points: assignment.points_possible,
                dueDate: formattedDate,
                due_at: originalDueAt, // Use the original ISO string from the API
                html_url: assignment.html_url,
                courseName: course.name,
                courseCode: course.course_code || course.name,
                isSubmitted: isSubmitted,
                type: assignment.submission_types?.[0] || 'online_text_entry',
                course_name: course.name,
                course_id: course.id,
                points_possible: assignment.points_possible
              };

              console.log('Final processed assignment:', {
                name: processedAssignment.name,
                dueDate: processedAssignment.dueDate,
                due_at: processedAssignment.due_at,
                type: processedAssignment.type,
                raw_assignment_due_at: assignment.due_at,
                raw_assignment_lock_at: assignment.lock_at
              });

              return processedAssignment;
            }));

          console.log(`Processed assignments for course ${course.name}:`, assignmentsWithSubmissions);
          return assignmentsWithSubmissions;
        } catch (error) {
          console.error(`Error fetching assignments for course ${course.id}:`, error);
          return [];
        }
      });

      // Wait for all assignment fetches to complete
      const allAssignments = (await Promise.all(assignmentPromises))
        .flat();
      
      console.log('All assignments before sorting:', allAssignments);

      // Sort all assignments by course name first, then by due date
      const sortedAssignments = allAssignments.sort((a: CanvasAssignment, b: CanvasAssignment) => {
        // First sort by course name
        const courseCompare = (a.courseName || '').localeCompare(b.courseName || '');
        if (courseCompare !== 0) return courseCompare;

        // Then sort by due date
        if (!a.dueDate || a.dueDate === 'No due date') return 1;
        if (!b.dueDate || b.dueDate === 'No due date') return -1;
        const dateA = new Date(a.dueDate.replace(' at ', ' '));
        const dateB = new Date(b.dueDate.replace(' at ', ' '));
        return dateA.getTime() - dateB.getTime();
      });

      console.log('Sorted assignments:', sortedAssignments);

      // Group assignments by course and sort by due date within each group
      const groupedAssignments: GroupedAssignments = {};
      sortedAssignments.forEach((assignment: CanvasAssignment) => {
        const courseCode = assignment.courseCode || '';
        if (!groupedAssignments[courseCode]) {
          groupedAssignments[courseCode] = {
            courseName: assignment.courseName || '',
            courseCode: courseCode,
            assignments: []
          };
        }
        groupedAssignments[courseCode].assignments.push(assignment);
      });

      // Sort assignments by due date within each course
      Object.values(groupedAssignments).forEach(group => {
        group.assignments.sort((a, b) => {
          if (!a.dueDate || a.dueDate === 'No due date') return 1;
          if (!b.dueDate || b.dueDate === 'No due date') return -1;
          const dateA = new Date(a.dueDate.replace(' at ', ' '));
          const dateB = new Date(b.dueDate.replace(' at ', ' '));
          return dateA.getTime() - dateB.getTime();
        });
      });

      console.log('Grouped and sorted assignments:', groupedAssignments);

      if (Object.keys(groupedAssignments).length === 0) {
        console.log('No assignments found after processing');
        setError('No assignments found. Make sure you have active courses with assignments.');
        return;
      }

      // Convert the grouped assignments back to the format expected by the component
      const formattedCourses = Object.values(groupedAssignments).map(group => ({
        id: group.courseCode,
        name: group.courseName,
        assignments: group.assignments.map(assignment => {
          let parsedDueAt = null;
          if (assignment.dueDate && assignment.dueDate !== 'No due date') {
            try {
              // Parse the date string carefully
              const [datePart, timePart] = assignment.dueDate.split(' at ');
              const [day, month] = datePart.split(' ');
              const [hours, minutes] = timePart.split(':');
              
              // Convert month name to month number (0-11)
              const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
              const monthIndex = months.indexOf(month);
              
              // Get current year
              const currentYear = new Date().getFullYear();
              
              // Create date object using 24-hour format
              const date = new Date(currentYear, monthIndex, parseInt(day), parseInt(hours), parseInt(minutes));
              
              // Only use ISO string if date is valid
              if (!isNaN(date.getTime())) {
                parsedDueAt = date.toISOString();
                console.log('Successfully parsed date:', {
                  original: assignment.dueDate,
                  parsed: date,
                  iso: parsedDueAt
                });
              }
            } catch (error) {
              console.warn('Failed to parse date:', assignment.dueDate, error);
            }
          }

          return {
            ...assignment,
            course_id: group.courseCode,
            course_name: group.courseName,
            due_at: parsedDueAt,
            points_possible: assignment.points,
            type: assignment.type
          };
        }),
        workflow_state: 'available',
        end_at: null,
        start_at: null,
        enrollment_term_id: 0,
      } as CanvasCourse));

      console.log('Final formatted courses:', formattedCourses);
      setCourses(formattedCourses);
      
      // At the end of the function:
      const allProcessedAssignments = Object.values(groupedAssignments)
        .flatMap(group => group.assignments);
      
      console.log('Storing all processed assignments:', allProcessedAssignments.length);
      setCanvasAssignments(allProcessedAssignments);
      
      // After successfully fetching assignments, check if we should show the subscription modal
      const hasShownSubscription = await AsyncStorage.getItem('hasShownSubscriptionAfterCanvas');
      if (!hasShownSubscription) {
        console.log('Flagging to show subscription modal after successful fetch');
        await AsyncStorage.setItem('hasShownSubscriptionAfterCanvas', 'true');

        // Check if the global function exists and call it
        // NOTE: This relies on App.tsx setting up window.TodoAppSubscription.showSubscriptionModal
        setTimeout(() => {
          if (typeof window !== 'undefined' &&
              window.TodoAppSubscription &&
              typeof window.TodoAppSubscription.showSubscriptionModal === 'function') {
             console.log('[CanvasIntegration] Calling global showSubscriptionModal');
             window.TodoAppSubscription.showSubscriptionModal();
          } else {
             console.warn('[CanvasIntegration] showSubscriptionModal function is not available on window.TodoAppSubscription. Flagging for next start.');
             // Fallback: set flag for next app start
             AsyncStorage.setItem('showSubscriptionOnNextStart', 'true');
          }
        }, 1000);
      }
      
      // Set loading state to false
      setLoading(false);
    } catch (error) {
      console.error('Error fetching assignments:', error);
      if (error instanceof Error && error.message.includes('Invalid API key')) {
        setError('Invalid API key. Please check your API key and try again.');
        handleRemoveApiKey();
      } else {
      setError(
        error instanceof Error 
          ? error.message 
          : 'Failed to fetch assignments. Please check your API key and try again.'
      );
      }
    }
  };

  const handlePressAnimation = (callback: () => void) => {
    callback();
  };

  const renderDropdown = (
    items: string[],
    selectedItem: string,
    onSelect: (item: string) => void,
    visible: boolean,
    onClose: () => void
  ) => (
    <Modal
      visible={visible}
      transparent={true}
      animationType="fade"
      onRequestClose={onClose}
    >
      <TouchableOpacity
        style={dynamicStyles.dropdownOverlay}
        activeOpacity={1}
        onPress={onClose}
      >
        <View style={[
          dynamicStyles.dropdownContent,
          isDarkMode && dynamicStyles.darkDropdownContent
        ]}>
          {items.map((item) => (
            <TouchableOpacity
              key={item}
              style={dynamicStyles.dropdownItem}
              onPress={() => {
                onSelect(item);
                onClose();
              }}
            >
              <Text style={[
                dynamicStyles.dropdownText,
                isDarkMode && dynamicStyles.darkText,
                item === selectedItem && dynamicStyles.selectedDropdownText
              ]}>
                {item}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </TouchableOpacity>
    </Modal>
  );

  const handleUniversitySelect = React.useCallback((university: University) => {
    setSelectedUniversity(university);
    setError(null);
    
    // Check if custom university is selected
    if (university.name === 'Custom University') {
      setIsCustomUniversity(true);
      // Only set initial values if they're empty
      if (!customUniversityName) setCustomUniversityName('');
      if (!customUniversityUrl) setCustomUniversityUrl('https://');
    } else {
      setIsCustomUniversity(false);
    }
    
    setShowUniversityDropdown(false);
    setIsUniversityDropdownOpen(false);
    console.log('Selected university:', university);
  }, [customUniversityName, customUniversityUrl]);

  const handleCloseModal = React.useCallback(() => {
    setShowApiKeyModal(false);
    setShowUniversityDropdown(false);
    setIsUniversityDropdownOpen(false);
    setError(null);
  }, []);

  const handleShowApiGuide = () => {
    setShowApiGuide(true);
    setShowApiKeyModal(false);
  };

  const renderAssignmentRow = (assignment: CanvasAssignment) => (
    <AssignmentRow 
      key={assignment.id} 
      assignment={assignment}
      isDarkMode={isDarkMode}
      onAssignmentSelect={onAssignmentSelect}
      availableHeaders={availableHeaders}
      themeColor={themeColor}
      currentTier={currentTier}
      checkHeaderLimit={checkHeaderLimit}
    />
  );

  const renderCourseSection = ({ item }: { item: { courseName: string; assignments: CanvasAssignment[] } }) => (
    <View>
      <View style={dynamicStyles.courseHeader}>
        <Text style={dynamicStyles.courseHeaderText}>{item.courseName}</Text>
      </View>
      <View>
        {item.assignments.map(assignment => (
          <AssignmentRow 
            key={assignment.id} 
            assignment={assignment}
            isDarkMode={isDarkMode}
            onAssignmentSelect={onAssignmentSelect}
            availableHeaders={availableHeaders}
            themeColor={themeColor}
            currentTier={currentTier}
            checkHeaderLimit={checkHeaderLimit}
          />
        ))}
      </View>
    </View>
  );

  const groupedAssignmentsBySection = useMemo(() => {
    if (selectedCourse === 'All Courses') {
      return Object.entries(
        filteredAssignments.reduce((acc, assignment) => {
          const courseCode = assignment.course_name || '';
          if (!acc[courseCode]) {
            acc[courseCode] = {
              courseName: courseCode,
              assignments: []
            };
          }
          acc[courseCode].assignments.push(assignment);
          return acc;
        }, {} as Record<string, { courseName: string; assignments: CanvasAssignment[] }>)
      ).map(([_, value]) => value);
    } else {
      return [{
        courseName: selectedCourse,
        assignments: filteredAssignments
      }];
    }
  }, [filteredAssignments, selectedCourse]);

  // Add a direct button in the UI to trigger the subscription modal for testing
  // Find a suitable place in the render function, perhaps near any settings or options buttons
  /* 
  Example UI addition (you can place this in a suitable spot):
  
  <TouchableOpacity 
    style={styles.optionButton} 
    onPress={showSubscriptionModal}
  >
    <Text style={[styles.optionButtonText, isDarkMode && styles.darkText]}>
      View Plans
    </Text>
  </TouchableOpacity>
  */

  return (
    <View style={[dynamicStyles.container, { flex: 1, minHeight: 100 }]}>
      <View style={dynamicStyles.headerContainer}>
        <Text style={dynamicStyles.headerTitle}>Canvas Integration</Text>
      </View>

      <View style={dynamicStyles.canvasContentWrapper}>
        <View style={dynamicStyles.canvasActions}>
          <TouchableOpacity
            style={dynamicStyles.loadButton}
            onPress={hasStoredApiKey ? fetchAssignments : () => setShowApiKeyModal(true)}
          >
            <Text style={dynamicStyles.loadButtonText}>
              {hasStoredApiKey ? 'FETCH ASSIGNMENTS' : 'CONNECT CANVAS'}
            </Text>
          </TouchableOpacity>

          {hasStoredApiKey && (
            <>
              <TouchableOpacity
                style={[
                  dynamicStyles.removeKeyButton,
                  isDarkMode && dynamicStyles.darkRemoveKeyButton
                ]}
                onPress={handleRemoveApiKey}
              >
                <Text style={dynamicStyles.removeKeyButtonText}>
                  DISCONNECT
                </Text>
              </TouchableOpacity>
            </>
          )}
        </View>

        {/* Show filters whenever courses exist, not just after fetching */}
        {courses.length > 0 && (
          <View style={dynamicStyles.filtersContainer}>
            <TouchableOpacity
              onPress={() => setShowCourseDropdown(true)}
              style={[
                dynamicStyles.courseFilterButton,
                isDarkMode && dynamicStyles.darkCourseFilterButton
              ]}
            >
              <Text style={isDarkMode ? dynamicStyles.darkText : { color: '#333' }}>
                {selectedCourse}
              </Text>
            </TouchableOpacity>
            
            <TouchableOpacity
              onPress={() => setShowTypeDropdown(true)}
              style={[
                dynamicStyles.courseFilterButton,
                isDarkMode && dynamicStyles.darkCourseFilterButton
              ]}
            >
              <Text style={isDarkMode ? dynamicStyles.darkText : { color: '#333' }}>
                {selectedType}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {loading && (
          <View style={dynamicStyles.loadingContainer}>
            <ActivityIndicator size="large" color={themeColor} />
            <Text style={[
              dynamicStyles.loadingText,
              isDarkMode && dynamicStyles.darkText
            ]}>
              Loading assignments...
            </Text>
          </View>
        )}

        {error && (
          <Text style={dynamicStyles.errorText}>{error}</Text>
        )}

        {!loading && filteredAssignments.length > 0 && (
          <ScrollView 
            style={dynamicStyles.assignmentsContainer} // Apply the flex: 1 style
            contentContainerStyle={{ paddingBottom: 20 }} // Reduced padding inside scroll view
            nestedScrollEnabled={true}
            showsVerticalScrollIndicator={true}
          >
            {groupedAssignmentsBySection.map((section) => (
              <View key={section.courseName}>
                <View style={dynamicStyles.courseHeader}>
                  <Text style={dynamicStyles.courseHeaderText}>{section.courseName}</Text>
                </View>
                {section.assignments.map(assignment => (
                  <AssignmentRow 
                    key={assignment.id} 
                    assignment={assignment}
                    isDarkMode={isDarkMode}
                    onAssignmentSelect={onAssignmentSelect}
                    availableHeaders={availableHeaders}
                    themeColor={themeColor}
                    currentTier={currentTier}
                    checkHeaderLimit={checkHeaderLimit}
                  />
                ))}
              </View>
            ))}
          </ScrollView>
        )}
        
        {!loading && !error && filteredAssignments.length === 0 && (
          <View style={{ padding: 20, alignItems: 'center' }}>
            <Text style={[
              { fontSize: 16, marginBottom: 20, textAlign: 'center' },
              isDarkMode && dynamicStyles.darkText
            ]}>
              {hasStoredApiKey 
                ? "No assignments found. Click the button above to fetch your assignments." 
                : "Connect your Canvas account to see your assignments."}
            </Text>
            
            {!loading && hasStoredApiKey && (
              <TouchableOpacity
                style={[
                  {
                    backgroundColor: themeColor,
                    paddingVertical: 12,
                    paddingHorizontal: 20,
                    borderRadius: 10,
                    alignSelf: 'center'
                  }
                ]}
                onPress={fetchAssignments}
              >
                <Text style={{ color: '#fff', fontWeight: 'bold' }}>
                  RETRY FETCH
                </Text>
              </TouchableOpacity>
            )}
          </View>
        )}
      </View>

      {/* All Modals - keep these outside of the ScrollView */}
      <Modal
        visible={showApiKeyModal}
        transparent={true}
        animationType="fade"
        onRequestClose={handleCloseModal}
      >
        {/* API Key Modal Content */}
        <View style={dynamicStyles.modalOverlay}>
          <View style={[
            dynamicStyles.modalContent,
            isDarkMode && dynamicStyles.darkModalContent
          ]}>
            {/* Modal Header */}
            <View style={dynamicStyles.modalHeader}>
              <Text style={[
                dynamicStyles.modalTitle,
                isDarkMode && dynamicStyles.darkText
              ]}>
                Connect to Canvas
              </Text>
              <TouchableOpacity
                style={dynamicStyles.closeButtonContainer}
                onPress={handleCloseModal}
              >
                <Text style={[dynamicStyles.closeButtonText, isDarkMode && dynamicStyles.darkText]}>✕</Text>
              </TouchableOpacity>
            </View>

            <Text style={[
              dynamicStyles.modalDescription,
              isDarkMode && dynamicStyles.darkText
            ]}>
              Select your university and enter your Canvas API key. You can find your API key in your Canvas account settings.
            </Text>
            
            {/* University Selection */}
            <Text style={[
              { fontSize: 16, fontWeight: '600', marginBottom: 8 },
              isDarkMode && dynamicStyles.darkText
            ]}>
              University:
            </Text>
            
            <View style={dynamicStyles.universityDropdownContainer}>
              <TouchableOpacity
                style={[
                  dynamicStyles.universitySelector,
                  isDarkMode && dynamicStyles.darkUniversitySelector
                ]}
                onPress={() => setIsUniversityDropdownOpen(!isUniversityDropdownOpen)}
                activeOpacity={0.7}
              >
                <Text style={[
                  dynamicStyles.universitySelectorText,
                  isDarkMode && dynamicStyles.darkText
                ]}>
                  {isCustomUniversity && customUniversityName 
                    ? customUniversityName 
                    : selectedUniversity.name}
                </Text>
                {/* Dropdown indicator removed */}
              </TouchableOpacity>
              
              {isUniversityDropdownOpen && (
                <View style={dynamicStyles.universityDropdownList}>
                  <ScrollView style={{ maxHeight: 200 }}>
                    {UNIVERSITIES.map((university) => (
                      <TouchableOpacity
                        key={university.url}
                        style={dynamicStyles.universityDropdownItem}
                        onPress={() => {
                          handleUniversitySelect(university);
                          setIsUniversityDropdownOpen(false);
                        }}
                      >
                        <Text style={[
                          dynamicStyles.universityDropdownItemText,
                          university.name === selectedUniversity.name && dynamicStyles.selectedUniversityText
                        ]}>
                          {university.name}
                        </Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </View>
              )}
            </View>
            
            {/* Custom University Inputs */}
            {isCustomUniversity && (
              <View style={{ marginBottom: 16 }}>
                <Text style={[
                  { fontSize: 16, fontWeight: '600', marginBottom: 8 },
                  isDarkMode && dynamicStyles.darkText
                ]}>
                  Custom University Details:
                </Text>
                <TextInput
                  style={[
                    dynamicStyles.input,
                    isDarkMode && dynamicStyles.darkInput,
                    { marginBottom: 8 }
                  ]}
                  placeholder="Enter University Name"
                  placeholderTextColor={colors.textSecondary}
                  value={customUniversityName}
                  onChangeText={setCustomUniversityName}
                />
                <TextInput
                  style={[
                    dynamicStyles.input,
                    isDarkMode && dynamicStyles.darkInput
                  ]}
                  placeholder="Enter Canvas URL (e.g., https://canvas.example.edu)"
                  placeholderTextColor={colors.textSecondary}
                  value={customUniversityUrl}
                  onChangeText={setCustomUniversityUrl}
                  autoCapitalize="none"
                  keyboardType="url"
                />
              </View>
            )}
            
            {/* API Key Input */}
            <Text style={[
              { fontSize: 16, fontWeight: '600', marginBottom: 8 },
              isDarkMode && dynamicStyles.darkText
            ]}>
              API Key:
            </Text>
            
            <View style={dynamicStyles.apiKeyContainer}>
              <TextInput
                style={[
                  dynamicStyles.input,
                  isDarkMode && dynamicStyles.darkInput
                ]}
                placeholder="Enter your Canvas API key"
                placeholderTextColor={colors.textSecondary}
                value={apiKey}
                onChangeText={setApiKey}
                secureTextEntry
              />
              <TouchableOpacity
                style={dynamicStyles.helpButton}
                onPress={handleShowApiGuide}
              >
                <FontAwesomeIcon 
                  icon={faQuestionCircle} 
                  size={20} 
                  color={themeColor}
                />
              </TouchableOpacity>
            </View>
            
            {error && (
              <Text style={dynamicStyles.errorText}>{error}</Text>
            )}
            
            <View style={dynamicStyles.modalButtons}>
              <TouchableOpacity
                style={[dynamicStyles.modalButton, dynamicStyles.cancelButton]}
                onPress={handleCloseModal}
              >
                <Text style={dynamicStyles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[dynamicStyles.modalButton, dynamicStyles.saveButton]}
                onPress={handleSaveApiKey}
              >
                <Text style={dynamicStyles.buttonText}>Connect</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Course/Type dropdown rendering */}
      {renderDropdown(
        ['All Courses', ...courses.map(c => c.name)],
        selectedCourse,
        setSelectedCourse,
        showCourseDropdown,
        () => setShowCourseDropdown(false)
      )}

      {renderDropdown(
        types,
        selectedType,
        setSelectedType,
        showTypeDropdown,
        () => setShowTypeDropdown(false)
      )}

      {/* API Key Guide Modal */}
      <Modal
        visible={showApiGuide}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowApiGuide(false)}
      >
        <View style={dynamicStyles.modalOverlay}>
          <View style={[
            dynamicStyles.modalContent,
            isDarkMode && dynamicStyles.darkModalContent,
            dynamicStyles.apiGuideModal
          ]}>
            <View style={dynamicStyles.modalHeader}>
              <Text style={[dynamicStyles.modalTitle, isDarkMode && dynamicStyles.darkText]}>
                How to Get Your Canvas API Key
              </Text>
              <TouchableOpacity
                style={dynamicStyles.closeButtonContainer}
                onPress={() => setShowApiGuide(false)}
              >
                <Text style={[dynamicStyles.closeButtonText, isDarkMode && dynamicStyles.darkText]}>✕</Text>
              </TouchableOpacity>
            </View>
            
            <ScrollView style={dynamicStyles.apiGuideContent}>
              <View style={dynamicStyles.apiGuideStep}>
                <Text style={[dynamicStyles.apiGuideStepNumber, isDarkMode && dynamicStyles.darkText]}>1</Text>
                <View style={dynamicStyles.apiGuideStepContent}>
                  <Text style={[dynamicStyles.apiGuideStepTitle, isDarkMode && dynamicStyles.darkText]}>
                    Go to Canvas Settings
                  </Text>
                  <Text style={[dynamicStyles.apiGuideStepDescription, isDarkMode && dynamicStyles.darkText]}>
                    Visit your Canvas profile settings page
                  </Text>
                  <TouchableOpacity
                    style={dynamicStyles.apiGuideLinkButton}
                    onPress={() => Linking.openURL(`${selectedUniversity.url}/profile/settings`)}
                  >
                    <Text style={dynamicStyles.apiGuideLinkButtonText}>Open Canvas Settings</Text>
                  </TouchableOpacity>
                </View>
              </View>

              <View style={dynamicStyles.apiGuideStep}>
                <Text style={[dynamicStyles.apiGuideStepNumber, isDarkMode && dynamicStyles.darkText]}>2</Text>
                <View style={dynamicStyles.apiGuideStepContent}>
                  <Text style={[dynamicStyles.apiGuideStepTitle, isDarkMode && dynamicStyles.darkText]}>
                    Find Approved Integrations
                  </Text>
                  <Text style={[dynamicStyles.apiGuideStepDescription, isDarkMode && dynamicStyles.darkText]}>
                    Scroll down to the "Approved Integrations" section
                  </Text>
                </View>
              </View>

              <View style={dynamicStyles.apiGuideStep}>
                <Text style={[dynamicStyles.apiGuideStepNumber, isDarkMode && dynamicStyles.darkText]}>3</Text>
                <View style={dynamicStyles.apiGuideStepContent}>
                  <Text style={[dynamicStyles.apiGuideStepTitle, isDarkMode && dynamicStyles.darkText]}>
                    Generate New Token
                  </Text>
                  <Text style={[dynamicStyles.apiGuideStepDescription, isDarkMode && dynamicStyles.darkText]}>
                    Click the "+ New Access Token" button and generate a new token
                  </Text>
                </View>
              </View>

              <View style={dynamicStyles.apiGuideStep}>
                <Text style={[dynamicStyles.apiGuideStepNumber, isDarkMode && dynamicStyles.darkText]}>4</Text>
                <View style={dynamicStyles.apiGuideStepContent}>
                  <Text style={[dynamicStyles.apiGuideStepTitle, isDarkMode && dynamicStyles.darkText]}>
                    Copy and Paste
                  </Text>
                  <Text style={[dynamicStyles.apiGuideStepDescription, isDarkMode && dynamicStyles.darkText]}>
                    Copy the generated token and paste it into the API key field in the app
                  </Text>
                </View>
              </View>

              <View style={dynamicStyles.apiGuideNote}>
                <Text style={[dynamicStyles.apiGuideNoteText, isDarkMode && dynamicStyles.darkText]}>
                  Note: Make sure to copy your token immediately after generating it, as you won't be able to see it again!
                </Text>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>

    </View>
  );
}

const AssignmentRow = ({ 
  assignment, 
  isDarkMode,
  onAssignmentSelect,
  availableHeaders = [],
  themeColor,
  currentTier = 'free',
  checkHeaderLimit
}: AssignmentRowProps) => {
  const [showHeaderModal, setShowHeaderModal] = useState(false);
  const [selectedHeader, setSelectedHeader] = useState('');
  const [newHeaderName, setNewHeaderName] = useState('');
  const [isCreatingNew, setIsCreatingNew] = useState(false);
  const [showHeaderDropdown, setShowHeaderDropdown] = useState(false);
  
  // Check if header limit reached (3 headers for free tier only)
  const isHeaderLimitReached = currentTier === 'free' && availableHeaders.length >= 3;
  const isPremiumUser = currentTier === 'student' || currentTier === 'lifetime';
  
  // Debug log current tier and header limit status
  console.log('[DEBUG] AssignmentRow - Current Tier:', currentTier, 
    'Premium User:', isPremiumUser, 
    'Header Count:', availableHeaders.length, 
    'Limit Reached:', isHeaderLimitReached);

  // Function to get days left text
  const getDaysLeftText = (assignment: CanvasAssignment) => {
    if (!assignment.dueDate || assignment.dueDate === 'No due date') {
      return 'No due date';
    }
    
    try {
      // Handle different date formats that might come from Canvas
      let dueDate: Date;
      
      if (assignment.due_at) {
        // If we have the original due_at from Canvas API, use it directly
        dueDate = new Date(assignment.due_at);
      } else if (assignment.dueDate.includes(' at ')) {
        // If it's in the format "23 Apr at 23:59"
        dueDate = new Date(assignment.dueDate.replace(' at ', ' '));
      } else {
        // Fallback to trying to parse the dueDate directly
        dueDate = new Date(assignment.dueDate);
      }
      
      // Check if date is valid
      if (isNaN(dueDate.getTime())) {
        return 'Date pending';
      }
      
      const now = new Date();
      
      // Reset time to midnight for date comparison
      now.setHours(0, 0, 0, 0);
      
      // Create a new date object for due date with time reset for day comparison
      const dueDateForComparison = new Date(dueDate);
      dueDateForComparison.setHours(0, 0, 0, 0);
      
      // Calculate days difference
      const diffTime = dueDateForComparison.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      
      if (diffDays < 0) {
        return `${Math.abs(diffDays)} ${Math.abs(diffDays) === 1 ? 'day' : 'days'} overdue`;
      } else if (diffDays === 0) {
        return 'Due today';
      } else if (diffDays === 1) {
        return 'Due tomorrow';
      } else {
        return `${diffDays} days left`;
      }
    } catch (e) {
      console.error('Error parsing date:', e, assignment.dueDate);
      return 'Date error';
    }
  };

  // Calculate relative due date
  const relativeDueDate = useMemo(() => {
    return getDaysLeftText(assignment);
  }, [assignment]);

  // Handle opening links
  const handleOpenLink = (url: string) => {
    Linking.openURL(url).catch((err) => console.error('Error opening URL:', err));
  };
  
  // Create styles for the component
  const dynamicStyles = useMemo(() => StyleSheet.create({
    // Assignment row styles
    assignmentRow: {
      padding: 16,
      backgroundColor: isDarkMode ? '#2a2a2a' : '#ffffff',
      borderRadius: 12,
      marginBottom: 14,
      marginHorizontal: 2,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 3,
      borderWidth: isDarkMode ? 0 : 1,
      borderColor: isDarkMode ? 'transparent' : '#f0f0f0',
    },
    darkAssignmentRow: {
      backgroundColor: '#2a2a2a',
    },
    assignmentContent: {
      flex: 1,
    },
    assignmentName: {
      fontSize: 17,
      fontWeight: '600',
      marginBottom: 10,
      color: isDarkMode ? '#ffffff' : '#333333',
      flexWrap: 'wrap',
    },
    darkText: {
      color: '#ffffff',
    },
    assignmentMeta: {
      gap: 10,
    },
    badgeContainer: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: 8,
      marginBottom: 6,
    },
    badge: {
      paddingHorizontal: 10,
      paddingVertical: 5,
      borderRadius: 12,
      alignItems: 'center',
      justifyContent: 'center',
    },
    typeBadge: {
      backgroundColor: isDarkMode ? '#444444' : '#f0f0f0',
    },
    typeBadgeText: {
      fontSize: 12,
      color: isDarkMode ? '#cccccc' : '#666666',
      fontWeight: '600',
    },
    submittedBadge: {
      backgroundColor: '#4CAF50',
    },
    notSubmittedBadge: {
      backgroundColor: '#FF5722',
    },
    badgeText: {
      fontSize: 12,
      color: '#ffffff',
      fontWeight: '600',
    },
    dueDateContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      flexWrap: 'wrap',
      gap: 10,
      marginBottom: 12,
    },
    dueDate: {
      fontSize: 14,
      color: isDarkMode ? '#cccccc' : '#666666',
      fontWeight: '500',
    },
    overdueBubble: {
      backgroundColor: '#FF5252',
      paddingHorizontal: 10,
      paddingVertical: 5,
    },
    dueSoonBubble: {
      backgroundColor: '#FF9800',
      paddingHorizontal: 10,
      paddingVertical: 5,
    },
    daysLeftBubble: {
      backgroundColor: isDarkMode ? '#444444' : '#e0e0e0',
      paddingHorizontal: 10,
      paddingVertical: 5,
    },
    actionButtons: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      gap: 10,
      marginTop: 10,
    },
    viewButton: {
      paddingHorizontal: 14,
      paddingVertical: 10,
      borderRadius: 8,
      backgroundColor: isDarkMode ? `${themeColor}60` : `${themeColor}80`,
      flex: 1,
      alignItems: 'center',
    },
    viewButtonText: {
      fontSize: 12,
      fontWeight: 'bold',
      color: '#ffffff',
    },
    actionAddButton: {
      paddingHorizontal: 14,
      paddingVertical: 10,
      borderRadius: 8,
      backgroundColor: themeColor,
      flex: 1,
      alignItems: 'center',
    },
    addButtonText: {
      fontSize: 12,
      fontWeight: 'bold',
      color: '#ffffff',
    },

    // Modal styles
    modalOverlay: {
      flex: 1,
      backgroundColor: 'rgba(0, 0, 0, 0.6)',
      justifyContent: 'center',
      alignItems: 'center',
      padding: 20,
    },
    modalContent: {
      backgroundColor: '#ffffff',
      borderRadius: 16,
      padding: 24,
      width: '100%',
      maxWidth: 400,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 5 },
      shadowOpacity: 0.25,
      shadowRadius: 10,
      elevation: 5,
    },
    darkModalContent: {
      backgroundColor: '#333333',
    },
    modalTitle: {
      fontSize: 20,
      fontWeight: 'bold',
      marginBottom: 20,
      textAlign: 'center',
      color: '#333333',
    },
    headerSelector: {
      marginBottom: 16,
    },
    optionSelector: {
      flexDirection: 'row',
      alignItems: 'center',
      padding: 14,
      backgroundColor: '#f0f0f0',
      borderRadius: 10,
      marginBottom: 10,
    },
    selectedOptionSelector: {
      backgroundColor: `${themeColor}15`, // 15 = 8% opacity
    },
    darkHeaderSelector: {
      backgroundColor: '#444444',
    },
    disabledButton: {
      opacity: 0.5,
    },
    optionSelectorInner: {
      flexDirection: 'row',
      alignItems: 'center',
    },
    radioButton: {
      width: 20,
      height: 20,
      borderRadius: 10,
      borderWidth: 2,
      borderColor: themeColor,
      marginRight: 12,
      alignItems: 'center',
      justifyContent: 'center',
    },
    radioButtonSelected: {
      backgroundColor: `${themeColor}20`, // 20 = 12% opacity
    },
    disabledRadioButton: {
      borderColor: '#999999',
    },
    radioButtonInner: {
      width: 10,
      height: 10,
      borderRadius: 5,
      backgroundColor: themeColor,
    },
    optionText: {
      fontSize: 16,
      color: '#333333',
    },
    disabledText: {
      color: '#999999',
    },
    dropdownContainer: {
      marginTop: 10,
    },
    enhancedDropdown: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: 14,
      borderWidth: 1,
      borderColor: '#ddd',
      borderRadius: 10,
      backgroundColor: '#f9f9f9',
    },
    darkEnhancedDropdown: {
      backgroundColor: '#444444',
      borderColor: '#555555',
    },
    dropdownText: {
      fontSize: 16,
      color: '#333333',
    },
    dropdownListContainer: {
      marginTop: 6,
      borderWidth: 1,
      borderColor: '#ddd',
      borderRadius: 10,
      backgroundColor: '#ffffff',
      maxHeight: 200,
      width: '100%',
      overflow: 'hidden',
    },
    darkDropdownListContainer: {
      backgroundColor: '#333333',
      borderColor: '#444444',
    },
    dropdownScroll: {
      maxHeight: 200,
    },
    dropdownItem: {
      padding: 14,
      borderBottomWidth: 1,
      borderBottomColor: '#f0f0f0',
    },
    selectedDropdownItem: {
      backgroundColor: `${themeColor}15`, // 15 = 8% opacity
    },
    darkDropdownItem: {
      borderBottomColor: '#444444',
    },
    dropdownItemText: {
      fontSize: 16,
      color: '#333333',
    },
    selectedDropdownItemText: {
      color: themeColor,
      fontWeight: 'bold',
    },
    headerOption: {
      padding: 14,
      borderBottomWidth: 1,
      borderBottomColor: '#f0f0f0',
    },
    selectedHeaderOption: {
      backgroundColor: `${themeColor}15`, // 15 = 8% opacity
    },
    headerOptionText: {
      fontSize: 16,
      color: '#333333',
    },
    enhancedInput: {
      padding: 14,
      borderWidth: 1,
      borderColor: '#ddd',
      borderRadius: 10,
      backgroundColor: '#f9f9f9',
      fontSize: 16,
      marginTop: 10,
    },
    darkEnhancedInput: {
      backgroundColor: '#444444',
      borderColor: '#555555',
      color: '#ffffff',
    },
    modalButtons: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      marginTop: 28,
    },
    modalButton: {
      flex: 1,
      paddingVertical: 14,
      paddingHorizontal: 16,
      borderRadius: 10,
      alignItems: 'center',
      justifyContent: 'center',
    },
    cancelButton: {
      backgroundColor: '#f0f0f0',
      marginRight: 10,
    },
    confirmButton: {
      marginLeft: 10,
    },
    cancelButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#666666',
    },
    confirmButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#ffffff',
    },
  }), [isDarkMode, themeColor]);

  // Create a handler that will be called when modal opens
  const handleAddToList = () => {
    // If no headers exist, set up for creating a new one
    // using the assignment's course name as default
    if (availableHeaders.length === 0) {
      setIsCreatingNew(true);
      setNewHeaderName(assignment.course_name || '');
    } else {
      // If headers exist, pre-select the first one
      setSelectedHeader(availableHeaders[0]);
    }
    
    // Check if we need to first verify header limit
    if (availableHeaders.length === 0 && currentTier === 'free' && isHeaderLimitReached) {
      Alert.alert(
        'Header Limit Reached',
        'Free users can only create up to 3 headers. Upgrade to create unlimited headers!',
        [{ text: 'OK' }]
      );
      return;
    }
    
    // Otherwise show the modal
    setShowHeaderModal(true);
  };
  
  const handleConfirmAdd = () => {
    let targetHeader = '';
    
    // Check if creating a new header
    if (isCreatingNew) {
      // Check if we can create a new header (for free tier)
      if (checkHeaderLimit) {
        // Use provided function to check limit
        if (!checkHeaderLimit()) {
          setShowHeaderModal(false);
          return;
        }
      } else if (currentTier === 'free' && isHeaderLimitReached) {
        // Fallback check if no function provided
        Alert.alert(
          'Header Limit Reached',
          'Free users can only create up to 3 headers. Upgrade to create unlimited headers!',
          [{ text: 'OK' }]
        );
        setShowHeaderModal(false);
        return;
      }
      
      // Ensure a header name was provided
      if (!newHeaderName.trim()) {
        Alert.alert('Please enter a header name');
        return;
      }
      targetHeader = newHeaderName.trim();
    } else {
      // Using an existing header
      if (!selectedHeader) {
        Alert.alert('Please select a header');
        return;
      }
      targetHeader = selectedHeader;
    }
    
    // Set the target header on the assignment
    const assignmentWithHeader = {
      ...assignment,
      targetHeader
    };
    
    // Pass to parent
    onAssignmentSelect(assignmentWithHeader);
    setShowHeaderModal(false);
  };

  const renderHeaderItem = ({ item }: { item: string }) => (
    <TouchableOpacity
      style={[
        dynamicStyles.headerOption,
        selectedHeader === item && dynamicStyles.selectedHeaderOption,
        isDarkMode && dynamicStyles.darkHeaderSelector
      ]}
      onPress={() => setSelectedHeader(item)}
    >
      <Text style={[
        dynamicStyles.headerOptionText,
        !isCreatingNew && { color: '#666', fontWeight: 'bold' },
        isDarkMode && dynamicStyles.darkText
      ]}>
        {item}
      </Text>
    </TouchableOpacity>
  );

  return (
    <>
      <View style={[dynamicStyles.assignmentRow, isDarkMode && dynamicStyles.darkAssignmentRow]}>
        <View style={dynamicStyles.assignmentContent}>
          <Text style={[dynamicStyles.assignmentName, isDarkMode && dynamicStyles.darkText]}>
            {assignment.name}
          </Text>
          <View style={dynamicStyles.assignmentMeta}>
            <View style={dynamicStyles.badgeContainer}>
              <View style={[dynamicStyles.badge, dynamicStyles.typeBadge]}>
                <Text style={dynamicStyles.typeBadgeText}>
                  {assignment.type?.toLowerCase().includes('quiz') ? 'Quiz' : 'Assignment'}
                </Text>
              </View>
              <View style={[
                dynamicStyles.badge, 
                assignment.isSubmitted 
                  ? dynamicStyles.submittedBadge 
                  : [dynamicStyles.notSubmittedBadge, { 
                      backgroundColor: `${themeColor}${isDarkMode ? 'B3' : '90'}` // Adjust opacity based on dark mode
                    }]
              ]}>
                <Text style={[
                  dynamicStyles.badgeText,
                  { 
                    color: '#ffffff',
                    fontWeight: '600'
                  }
                ]}>
                  {assignment.isSubmitted ? 'Submitted' : 'Not Submitted'}
                </Text>
              </View>
            </View>
            <View style={dynamicStyles.dueDateContainer}>
              <Text style={[dynamicStyles.dueDate, isDarkMode && dynamicStyles.darkText]}>
                {assignment.dueDate ? `Due: ${assignment.dueDate}` : 'No due date'}
              </Text>
              {relativeDueDate && (
                <View style={[
                  dynamicStyles.badge,
                  relativeDueDate.includes('overdue') 
                    ? [dynamicStyles.overdueBubble, { backgroundColor: `${themeColor}B3` }] // B3 = 70% opacity
                    : (relativeDueDate === 'Due today' || relativeDueDate === 'Due tomorrow' 
                      ? dynamicStyles.dueSoonBubble 
                      : dynamicStyles.daysLeftBubble)
                ]}>
                  <Text style={[
                    dynamicStyles.badgeText,
                    { 
                      color: relativeDueDate.includes('overdue') || relativeDueDate === 'Due today' || relativeDueDate === 'Due tomorrow' 
                        ? '#ffffff' 
                        : isDarkMode ? '#ffffff' : '#666666',
                      fontWeight: '600'
                    }
                  ]}>
                    {relativeDueDate}
                  </Text>
                </View>
              )}
            </View>
            <View style={dynamicStyles.actionButtons}>
              {assignment.html_url ? (
                <>
                  <TouchableOpacity
                    style={dynamicStyles.viewButton}
                    onPress={() => handleOpenLink(assignment.html_url!)}
                  >
                    <Text style={dynamicStyles.viewButtonText}>VIEW IN CANVAS</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={dynamicStyles.actionAddButton}
                    onPress={handleAddToList}
                  >
                    <Text style={dynamicStyles.addButtonText}>ADD TO LIST</Text>
                  </TouchableOpacity>
                </>
              ) : (
                <TouchableOpacity
                  style={[dynamicStyles.actionAddButton, { flex: 1 }]}
                  onPress={handleAddToList}
                >
                  <Text style={dynamicStyles.addButtonText}>ADD TO LIST</Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        </View>
      </View>
      
      {/* Modal for selecting header */}
      <Modal
        visible={showHeaderModal}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowHeaderModal(false)}
      >
        <View style={dynamicStyles.modalOverlay}>
          <View style={[
            dynamicStyles.modalContent,
            isDarkMode && dynamicStyles.darkModalContent
          ]}>
            <Text style={[
              dynamicStyles.modalTitle,
              isDarkMode && dynamicStyles.darkText
            ]}>
              Add Assignment to List
            </Text>

            <View style={dynamicStyles.headerSelector}>
              {availableHeaders.length > 0 ? (
                <View style={{ marginBottom: 16 }}>
                  <TouchableOpacity
                    style={[
                      dynamicStyles.optionSelector,
                      !isCreatingNew && dynamicStyles.selectedOptionSelector,
                      isDarkMode && dynamicStyles.darkHeaderSelector
                    ]}
                    onPress={() => setIsCreatingNew(false)}
                  >
                    <View style={dynamicStyles.optionSelectorInner}>
                      <View style={[
                        dynamicStyles.radioButton,
                        !isCreatingNew && dynamicStyles.radioButtonSelected
                      ]}>
                        {!isCreatingNew && <View style={dynamicStyles.radioButtonInner} />}
                      </View>
                      <Text style={[
                        dynamicStyles.optionText,
                        isDarkMode && dynamicStyles.darkText
                      ]}>
                        Select existing list
                      </Text>
                    </View>
                  </TouchableOpacity>

                  {!isCreatingNew && (
                    <View style={dynamicStyles.dropdownContainer}>
                      <TouchableOpacity
                        style={[
                          dynamicStyles.enhancedDropdown,
                          isDarkMode && dynamicStyles.darkEnhancedDropdown
                        ]}
                        onPress={() => setShowHeaderDropdown(!showHeaderDropdown)}
                      >
                        <Text style={[
                          dynamicStyles.dropdownText,
                          isDarkMode && dynamicStyles.darkText
                        ]}>
                          {selectedHeader || "Select a list"}
                        </Text>
                        {/* Remove dropdown icon container */}
                      </TouchableOpacity>

                      {showHeaderDropdown && (
                        <View style={[
                          dynamicStyles.dropdownListContainer,
                          isDarkMode && dynamicStyles.darkDropdownListContainer
                        ]}>
                          <ScrollView 
                            style={dynamicStyles.dropdownScroll} 
                            nestedScrollEnabled={true}
                            showsVerticalScrollIndicator={false}
                          >
                            {availableHeaders.map(item => (
                              <TouchableOpacity
                                key={item}
                                style={[
                                  dynamicStyles.dropdownItem,
                                  selectedHeader === item && dynamicStyles.selectedDropdownItem,
                                  isDarkMode && dynamicStyles.darkDropdownItem
                                ]}
                                onPress={() => {
                                  setSelectedHeader(item);
                                  setShowHeaderDropdown(false);
                                }}
                              >
                                <Text style={[
                                  dynamicStyles.dropdownItemText,
                                  selectedHeader === item && dynamicStyles.selectedDropdownItemText,
                                  isDarkMode && dynamicStyles.darkText
                                ]}>
                                  {item}
                                </Text>
                              </TouchableOpacity>
                            ))}
                          </ScrollView>
                        </View>
                      )}
                    </View>
                  )}
                </View>
              ) : null}

              <TouchableOpacity
                style={[
                  dynamicStyles.optionSelector,
                  isCreatingNew && dynamicStyles.selectedOptionSelector,
                  isDarkMode && dynamicStyles.darkHeaderSelector,
                  // Only apply disabled style for free tier when limit reached
                  currentTier === 'free' && isHeaderLimitReached && dynamicStyles.disabledButton
                ]}
                onPress={() => {
                  if (currentTier !== 'free' || !isHeaderLimitReached) {
                    setIsCreatingNew(true);
                    if (availableHeaders.length === 0) {
                      // Suggest course name as header name if no headers exist
                      setNewHeaderName(assignment.course_name || '');
                    }
                  } else {
                    Alert.alert('Upgrade Required', 'You\'ve reached the maximum number of lists. Upgrade to premium for unlimited lists.');
                  }
                }}
                disabled={currentTier === 'free' && isHeaderLimitReached}
              >
                <View style={dynamicStyles.optionSelectorInner}>
                  <View style={[
                    dynamicStyles.radioButton,
                    isCreatingNew && dynamicStyles.radioButtonSelected,
                    // Only apply disabled style for free tier when limit reached
                    currentTier === 'free' && isHeaderLimitReached && dynamicStyles.disabledRadioButton
                  ]}>
                    {isCreatingNew && <View style={dynamicStyles.radioButtonInner} />}
                  </View>
                  <Text style={[
                    dynamicStyles.optionText,
                    isDarkMode && dynamicStyles.darkText,
                    // Only apply disabled style for free tier when limit reached
                    currentTier === 'free' && isHeaderLimitReached && dynamicStyles.disabledText
                  ]}>
                    {availableHeaders.length > 0 ? 'Create new list' : 'Create your first list'}
                    {currentTier === 'free' && isHeaderLimitReached ? ' (Premium only)' : ''}
                  </Text>
                </View>
              </TouchableOpacity>

              {isCreatingNew && (
                <TextInput
                  style={[
                    dynamicStyles.enhancedInput,
                    isDarkMode && dynamicStyles.darkEnhancedInput
                  ]}
                  value={newHeaderName}
                  onChangeText={setNewHeaderName}
                  placeholder="Enter list name"
                  placeholderTextColor={isDarkMode ? '#999999' : '#999999'}
                />
              )}
            </View>

            <View style={dynamicStyles.modalButtons}>
              <TouchableOpacity
                style={[
                  dynamicStyles.modalButton, 
                  dynamicStyles.cancelButton
                ]}
                onPress={() => setShowHeaderModal(false)}
              >
                <Text style={[
                  dynamicStyles.cancelButtonText,
                  isDarkMode && { color: '#ffffff' }
                ]}>
                  Cancel
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[
                  dynamicStyles.modalButton,
                  dynamicStyles.confirmButton,
                  { backgroundColor: themeColor },
                  ((!isCreatingNew && !selectedHeader) || (isCreatingNew && !newHeaderName)) && 
                    dynamicStyles.disabledButton
                ]}
                onPress={handleConfirmAdd}
                disabled={(!isCreatingNew && !selectedHeader) || (isCreatingNew && !newHeaderName)}
              >
                <Text style={dynamicStyles.confirmButtonText}>
                  Add Assignment
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
};